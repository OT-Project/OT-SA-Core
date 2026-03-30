#!/usr/local/bin/python3

"""
    OT-SA SSH User Access Management — Apply per-user SSH configurations

    Reads the SshUser model config and:
    1. Writes authorized_keys for users with SSH public keys
    2. Updates user shells via pw usermod

    Copyright (C) 2024 Deciso B.V.
    All rights reserved.
"""

import subprocess
import os
import sys
import xml.etree.ElementTree as ET

CONFIG_PATH = '/conf/config.xml'
SSH_DIR_MODE = 0o700
AUTH_KEYS_MODE = 0o600


def get_ssh_users():
    """Parse SshUser entries from config.xml"""
    users = []
    try:
        tree = ET.parse(CONFIG_PATH)
        root = tree.getroot()
        sshuser_node = root.find('.//OPNsense/auth/sshuser/users')
        if sshuser_node is None:
            return users

        for user_node in sshuser_node.findall('user'):
            enabled = user_node.findtext('enabled', '0')
            if enabled != '1':
                continue

            username = user_node.findtext('username', '')
            if not username:
                continue

            users.append({
                'username': username,
                'sshPublicKey': user_node.findtext('sshPublicKey', ''),
                'shell': user_node.findtext('shell', '/usr/local/sbin/opnsense-shell'),
                'permissionGroup': user_node.findtext('permissionGroup', 'operator'),
            })
    except Exception as e:
        print(f"Error parsing config: {e}", file=sys.stderr)

    return users


def get_user_home(username):
    """Get the home directory for a user"""
    try:
        result = subprocess.run(
            ['pw', 'usershow', username, '-7'],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            # pw usershow -7 outputs just the shell, but we need home dir
            pass
    except Exception:
        pass

    # Use getent to get home directory
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

    # Fallback: root gets /root, others get /home/username
    if username == 'root':
        return '/root'
    return f'/home/{username}'


def write_authorized_keys(username, public_key):
    """Write SSH public key to user's authorized_keys file"""
    home_dir = get_user_home(username)
    ssh_dir = os.path.join(home_dir, '.ssh')

    # Create .ssh directory if needed
    if not os.path.isdir(ssh_dir):
        os.makedirs(ssh_dir, mode=SSH_DIR_MODE, exist_ok=True)
        # Set ownership to the user
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
        # No key — remove authorized_keys if it was managed by us
        if os.path.isfile(auth_keys_path):
            with open(auth_keys_path, 'r') as f:
                content = f.read()
            if 'OT-SA SSH Management' in content:
                os.remove(auth_keys_path)
                print(f"  [OK] Removed managed authorized_keys for {username}")


def update_user_shell(username, shell):
    """Update the user's login shell"""
    try:
        subprocess.run(
            ['pw', 'usermod', username, '-s', shell],
            check=True, capture_output=True
        )
        print(f"  [OK] Set shell for {username}: {shell}")
    except subprocess.CalledProcessError as e:
        print(f"  [WARN] Failed to set shell for {username}: {e.stderr}", file=sys.stderr)


def map_permission_group(username, group):
    """Map permission group to OPNsense system groups"""
    group_map = {
        'admin': 'admins',
        'operator': 'operator',
        'viewer': 'viewer',
    }
    target_group = group_map.get(group, 'operator')
    try:
        subprocess.run(
            ['pw', 'groupmod', target_group, '-m', username],
            check=True, capture_output=True
        )
        print(f"  [OK] Added {username} to group: {target_group}")
    except subprocess.CalledProcessError as e:
        # Group may not exist yet
        print(f"  [WARN] Could not add {username} to group {target_group}: {e.stderr}",
              file=sys.stderr)


if __name__ == '__main__':
    ssh_users = get_ssh_users()

    if not ssh_users:
        print("No enabled SSH users configured.")
        sys.exit(0)

    print(f"Applying SSH settings for {len(ssh_users)} user(s)...")

    for user in ssh_users:
        username = user['username']
        print(f"\n--- {username} ---")
        write_authorized_keys(username, user.get('sshPublicKey', ''))
        update_user_shell(username, user['shell'])
        map_permission_group(username, user['permissionGroup'])

    print("\nDone.")
