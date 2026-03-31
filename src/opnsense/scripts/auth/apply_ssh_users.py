#!/usr/local/bin/python3

"""
    OT-SA SSH User Access Management — Apply per-user SSH configurations

    Reads SSH-enabled users from /conf/config.xml (system/user entries with
    ssh_enabled=1) and writes authorized_keys for users who have public keys.

    Copyright (C) 2024 Deciso B.V.
    All rights reserved.
"""

import os
import sys
import base64
import subprocess
import xml.etree.ElementTree as ET

CONFIG_PATH = '/conf/config.xml'
SSH_DIR_MODE = 0o700
AUTH_KEYS_MODE = 0o600


def get_ssh_users():
    """Parse system users with ssh_enabled=1 from config.xml"""
    users = []
    try:
        tree = ET.parse(CONFIG_PATH)
        root = tree.getroot()

        for user_node in root.findall('.//system/user'):
            ssh_enabled = user_node.findtext('ssh_enabled', '0')
            disabled = user_node.findtext('disabled', '0')
            if ssh_enabled != '1' or disabled == '1':
                continue

            username = user_node.findtext('name', '')
            if not username:
                continue

            # Decode authorized keys (stored as base64 in config.xml)
            auth_keys_b64 = user_node.findtext('authorizedkeys', '')
            public_key = ''
            if auth_keys_b64 and auth_keys_b64.strip():
                try:
                    public_key = base64.b64decode(auth_keys_b64).decode('utf-8', errors='replace').strip()
                except Exception:
                    public_key = ''

            users.append({
                'username': username,
                'public_key': public_key,
            })
    except Exception as e:
        print(f"Error parsing config: {e}", file=sys.stderr)

    return users


def get_user_home(username):
    """Get the home directory for a user"""
    try:
        result = subprocess.run(
            ['getent', 'passwd', username],
            capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            parts = result.stdout.strip().split(':')
            if len(parts) >= 6:
                return parts[5]
    except Exception:
        pass

    if username == 'root':
        return '/root'
    return f'/home/{username}'


def write_authorized_keys(username, public_key):
    """Write SSH public key to user's authorized_keys file"""
    home_dir = get_user_home(username)
    ssh_dir = os.path.join(home_dir, '.ssh')

    if not os.path.isdir(ssh_dir):
        os.makedirs(ssh_dir, mode=SSH_DIR_MODE, exist_ok=True)
        try:
            subprocess.run(['chown', f'{username}:{username}', ssh_dir], check=True)
        except subprocess.CalledProcessError:
            subprocess.run(['chown', username, ssh_dir], check=False)

    auth_keys_path = os.path.join(ssh_dir, 'authorized_keys')

    if public_key.strip():
        header = '# OT-SA SSH Management — auto-generated, do not edit manually\n'
        with open(auth_keys_path, 'w') as f:
            f.write(header)
            f.write(public_key.strip() + '\n')
        os.chmod(auth_keys_path, AUTH_KEYS_MODE)
        try:
            subprocess.run(['chown', f'{username}:{username}', auth_keys_path], check=True)
        except subprocess.CalledProcessError:
            subprocess.run(['chown', username, auth_keys_path], check=False)
        print(f"  [OK] Wrote authorized_keys for {username}")
    else:
        # No key — remove authorized_keys if managed by us
        if os.path.isfile(auth_keys_path):
            with open(auth_keys_path, 'r') as f:
                content = f.read()
            if 'OT-SA SSH Management' in content:
                os.remove(auth_keys_path)
                print(f"  [OK] Removed managed authorized_keys for {username}")


if __name__ == '__main__':
    ssh_users = get_ssh_users()

    if not ssh_users:
        print("No SSH-enabled users configured.")
        sys.exit(0)

    print(f"Applying SSH settings for {len(ssh_users)} user(s)...")

    for user in ssh_users:
        username = user['username']
        print(f"\n--- {username} ---")
        write_authorized_keys(username, user['public_key'])

    print("\nDone.")
