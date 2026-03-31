#!/bin/sh

# OT-SA SSH User Access Management — Reconfigure Script
# Called by configd action: sshmanagement configure

set -e

TEMPLATE="OPNsense/Auth/SshManagement"
SSHD_DROPIN_DIR="/usr/local/etc/ssh/sshd_config.d"
SSHD_CONFIG_DROPIN="${SSHD_DROPIN_DIR}/otsa-sshmanagement.conf"

# Ensure drop-in directory exists
mkdir -p "${SSHD_DROPIN_DIR}"

echo "==> Rendering SSH management template..."
/usr/local/sbin/configctl template reload "${TEMPLATE}" 2>/dev/null || true

# Apply per-user authorized keys and shell settings
echo "==> Applying per-user SSH configurations..."
/usr/local/opnsense/scripts/auth/apply_ssh_users.py

# Validate sshd config before restarting
echo "==> Validating sshd configuration..."
if /usr/sbin/sshd -t 2>/dev/null; then
    echo "==> Configuration valid, restarting sshd..."
    /usr/sbin/service sshd restart
    echo "==> SSH reconfiguration complete."
else
    echo "!!! sshd configuration validation failed. NOT restarting sshd." >&2
    echo "!!! Check ${SSHD_CONFIG_DROPIN} for errors." >&2
    exit 1
fi
