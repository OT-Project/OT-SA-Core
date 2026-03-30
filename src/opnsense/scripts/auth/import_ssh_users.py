#!/usr/local/bin/python3

"""
    OT-SA SSH Management — Import existing users as SSH entries

    Reads system users from /conf/config.xml and creates initial SSH Management
    entries for users who have:
    - authorized_keys set, OR
    - are members of the 'wheel' group (SSH-capable), OR
    - are the root user

    Copyright (C) 2024 Deciso B.V.
    All rights reserved.
"""

import xml.etree.ElementTree as ET
import uuid
import base64
import sys
import json

CONFIG_PATH = '/conf/config.xml'

# Default shell paths in OPNsense
KNOWN_SHELLS = {
    '/usr/local/sbin/opnsense-shell': 'opnsense_shell',
    '/bin/sh': 'bourne_shell',
    '/bin/csh': 'c_shell',
    '/bin/tcsh': 'tenex_shell',
    '/usr/local/bin/bash': 'bash',
    '/usr/sbin/nologin': 'nologin',
}


def get_wheel_members(root):
    """Get list of UIDs in the wheel group"""
    wheel_uids = set()
    for group in root.findall('.//system/group'):
        name = group.findtext('name', '')
        if name == 'admins' or name == 'wheel':
            for member in group.findall('member'):
                if member.text:
                    wheel_uids.add(member.text.strip())
    return wheel_uids


def get_ssh_global_config(root):
    """Get global SSH auth method from config"""
    ssh_node = root.find('.//system/ssh')
    if ssh_node is None:
        return 'key_only'

    has_password = ssh_node.find('passwordauth') is not None
    if has_password:
        return 'both'
    return 'key_only'


def get_existing_ssh_entries(root):
    """Check if SSH Management entries already exist"""
    sshuser_node = root.find('.//OPNsense/auth/sshuser/users')
    if sshuser_node is None:
        return []
    entries = []
    for user_node in sshuser_node.findall('user'):
        username = user_node.findtext('username', '')
        if username:
            entries.append(username)
    return entries


def import_users():
    """Import existing system users into SSH Management model"""
    try:
        tree = ET.parse(CONFIG_PATH)
        root = tree.getroot()
    except Exception as e:
        print(json.dumps({'status': 'error', 'message': f'Failed to parse config: {e}'}))
        sys.exit(1)

    # Check for existing entries
    existing = get_existing_ssh_entries(root)
    if existing:
        print(json.dumps({
            'status': 'exists',
            'message': f'SSH Management already has {len(existing)} entries. Skipping import.',
            'existing_users': existing
        }))
        return

    # Get global SSH auth mode
    global_auth = get_ssh_global_config(root)
    wheel_uids = get_wheel_members(root)

    # Find or create the SshUser model node
    opnsense = root.find('.//OPNsense')
    if opnsense is None:
        opnsense = ET.SubElement(root, 'OPNsense')

    auth_node = opnsense.find('auth')
    if auth_node is None:
        auth_node = ET.SubElement(opnsense, 'auth')

    sshuser_node = auth_node.find('sshuser')
    if sshuser_node is None:
        sshuser_node = ET.SubElement(auth_node, 'sshuser')

    users_node = sshuser_node.find('users')
    if users_node is None:
        users_node = ET.SubElement(sshuser_node, 'users')

    imported = []

    for user_elem in root.findall('.//system/user'):
        username = user_elem.findtext('name', '')
        uid = user_elem.findtext('uid', '')
        disabled = user_elem.findtext('disabled', '0')
        shell = user_elem.findtext('shell', '')
        auth_keys_b64 = user_elem.findtext('authorizedkeys', '')

        if not username:
            continue

        # Skip disabled users
        if disabled == '1':
            continue

        # Determine if this user should get an SSH entry:
        # - Has authorized keys, OR
        # - Is in wheel/admins group, OR
        # - Is root
        has_keys = bool(auth_keys_b64 and auth_keys_b64.strip())
        is_wheel = uid in wheel_uids
        is_root = username == 'root' or uid == '0'

        if not (has_keys or is_wheel or is_root):
            continue

        # Decode authorized keys
        ssh_public_key = ''
        if has_keys:
            try:
                ssh_public_key = base64.b64decode(auth_keys_b64).decode('utf-8', errors='replace').strip()
            except Exception:
                ssh_public_key = ''

        # Determine shell mapping
        shell_value = 'opnsense_shell'
        if shell in KNOWN_SHELLS:
            shell_value = KNOWN_SHELLS[shell]

        # Determine permission group
        if is_root or is_wheel:
            perm_group = 'admin'
        else:
            perm_group = 'operator'

        # Determine auth method
        if has_keys and global_auth in ('both', 'key_only'):
            auth_method = 'key_only' if has_keys else global_auth
        elif has_keys:
            auth_method = 'key_only'
        else:
            auth_method = global_auth

        # Create the SSH user entry
        entry_uuid = str(uuid.uuid4())
        user_node = ET.SubElement(users_node, 'user', attrib={'uuid': entry_uuid})

        fields = {
            'enabled': '1',
            'username': username,
            'sshPublicKey': ssh_public_key,
            'authMethod': auth_method,
            'shell': shell_value,
            'permissionGroup': perm_group,
            'allowedNetworks': '',
            'sessionTimeout': '30',
            'maxSessions': '3',
            'portForwarding': '0',
        }

        for field_name, field_value in fields.items():
            elem = ET.SubElement(user_node, field_name)
            elem.text = field_value

        imported.append({
            'username': username,
            'uuid': entry_uuid,
            'authMethod': auth_method,
            'permissionGroup': perm_group,
            'hasKey': has_keys,
        })

    if imported:
        # Write back
        ET.indent(tree, space='  ')
        tree.write(CONFIG_PATH, xml_declaration=True, encoding='utf-8')
        print(json.dumps({
            'status': 'ok',
            'message': f'Imported {len(imported)} user(s) into SSH Management.',
            'users': imported
        }))
    else:
        print(json.dumps({
            'status': 'empty',
            'message': 'No eligible users found for SSH Management import.'
        }))


if __name__ == '__main__':
    import_users()
