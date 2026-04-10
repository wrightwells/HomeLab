#!/usr/bin/env bash
# fix-hostname-resolution.sh -- Fix Proxmox hostname resolution for cluster tools.
#
# Proxmox cluster tools (pvecm, pct) require the hostname to resolve to the
# management IP, NOT 127.0.0.1. This script ensures /etc/hostname is correct,
# removes stale or incorrect /etc/hosts entries, and writes the correct one
# pointing at 10.10.99.10.
#
# Usage: ./scripts/fix-hostname-resolution.sh

set -euo pipefail

EXPECTED_HOSTNAME="pve01.uk.wrightwells.com"
EXPECTED_SHORT="pve01"
MANAGEMENT_IP="10.10.99.10"

echo "=== Fixing Proxmox hostname ==="
echo "Expected hostname: ${EXPECTED_HOSTNAME}"
echo "Management IP: ${MANAGEMENT_IP}"

# ---------------------------------------------------------------------------
# 1. Fix /etc/hostname to the correct Proxmox hostname
# ---------------------------------------------------------------------------
if [ "$(cat /etc/hostname 2>/dev/null)" != "${EXPECTED_HOSTNAME}" ]; then
  echo "Fixing /etc/hostname from '$(cat /etc/hostname 2>/dev/null || echo "(empty)")' to '${EXPECTED_HOSTNAME}'"
  echo "${EXPECTED_HOSTNAME}" > /etc/hostname
else
  echo "/etc/hostname is already correct"
fi

# ---------------------------------------------------------------------------
# 2. Set the live hostname so changes take effect without reboot
# ---------------------------------------------------------------------------
CURRENT_HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
if [ "${CURRENT_HOSTNAME}" != "${EXPECTED_HOSTNAME}" ]; then
  echo "Setting live hostname from '${CURRENT_HOSTNAME}' to '${EXPECTED_HOSTNAME}'"
  hostnamectl set-hostname "${EXPECTED_HOSTNAME}"
else
  echo "Live hostname is already correct"
fi

# ---------------------------------------------------------------------------
# 3. Clean /etc/hosts: remove any line referencing pve01 OR vm050-mint
# ---------------------------------------------------------------------------
echo "Cleaning /etc/hosts of stale entries..."
sed -i '/pve01/d' /etc/hosts
sed -i '/vm050-mint/d' /etc/hosts

# ---------------------------------------------------------------------------
# 4. Add the correct entry pointing to the management IP
# ---------------------------------------------------------------------------
echo "${MANAGEMENT_IP} ${EXPECTED_HOSTNAME} ${EXPECTED_SHORT}" >> /etc/hosts

echo ""
echo "Updated /etc/hosts:"
cat /etc/hosts

echo ""
echo "=== Testing pvesh ==="
pvesh get /cluster/resources --output-format json 2>&1 | head -1 || echo "API call failed — check hostname again."
echo ""
echo "=== Hostname resolution fix complete ==="
