#!/usr/bin/env bash
# fix-hostname-resolution.sh -- Fix Proxmox hostname resolution for cluster tools.
#
# Proxmox cluster tools (pvecm, pct) require the hostname to resolve to the
# management IP, NOT 127.0.0.1. This script removes stale or incorrect entries
# and writes the correct one pointing at 10.10.99.10.
#
# Usage: ./scripts/fix-hostname-resolution.sh

set -euo pipefail

HOSTNAME_FQDN=$(hostname -f 2>/dev/null || echo "pve01.uk.wrightwells.com")
HOSTNAME_SHORT=$(hostname -s 2>/dev/null || echo "pve01")
MANAGEMENT_IP="10.10.99.10"

echo "=== Fixing hostname resolution ==="
echo "Hostname: ${HOSTNAME_FQDN}"
echo "Management IP: ${MANAGEMENT_IP}"

# Remove any existing lines that reference this hostname (both FQDN and short)
sed -i "/${HOSTNAME_SHORT}/d" /etc/hosts

# Add the correct entry pointing to the management IP, not 127.0.0.1
echo "${MANAGEMENT_IP} ${HOSTNAME_FQDN} ${HOSTNAME_SHORT}" >> /etc/hosts

echo "Updated /etc/hosts:"
cat /etc/hosts

echo ""
echo "=== Testing pvesh ==="
pvesh get /cluster/resources --output-format json 2>&1 | head -1 || echo "API call failed — check hostname again."
echo ""
echo "=== Hostname resolution fix complete ==="
