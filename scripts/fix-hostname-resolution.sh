#!/usr/bin/env bash
# fix-hostname-resolution.sh -- Fix Proxmox hostname resolution for cluster tools.
#
# Proxmox cluster tools (pvecm, pct) require the hostname to resolve to an IP.
# After a hostname change or fresh install, this script ensures /etc/hosts
# contains the correct entry.
#
# Usage: ./scripts/fix-hostname-resolution.sh

set -euo pipefail

HOSTNAME_FQDN=$(hostname -f 2>/dev/null || echo "pve01.uk.wrightwells.com")
HOSTNAME_SHORT=$(hostname -s 2>/dev/null || echo "pve01")

echo "=== Fixing hostname resolution ==="
echo "Hostname: ${HOSTNAME_FQDN}"

if grep -q "$HOSTNAME_SHORT" /etc/hosts; then
  echo "Hostname already in /etc/hosts."
else
  echo "127.0.0.1 ${HOSTNAME_FQDN} ${HOSTNAME_SHORT}" >> /etc/hosts
  echo "Added to /etc/hosts."
fi

echo ""
echo "Testing: pvesh get /cluster/resources --output-format json 2>&1 | head -1"
pvesh get /cluster/resources --output-format json 2>&1 | head -1 || echo "API call failed — check hostname again."
echo ""
echo "=== Hostname resolution fix complete ==="
