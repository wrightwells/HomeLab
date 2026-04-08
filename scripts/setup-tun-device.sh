#!/usr/bin/env bash
# setup-tun-device.sh -- Add /dev/net/tun to the docker-arr LXC for VPN passthrough.
#
# The ARR stack uses gluetun which requires /dev/net/tun. Unprivileged LXCs
# don't have this device by default. This script adds the necessary config
# to LXC 166 (docker-arr) and reboots it.
#
# Usage: ./scripts/setup-tun-device.sh [LXC_ID]
# Default LXC_ID: 166

set -euo pipefail

LXC_ID="${1:-166}"
CONF="/etc/pve/lxc/${LXC_ID}.conf"

echo "=== Adding /dev/net/tun to LXC ${LXC_ID} ==="

if [ ! -f "$CONF" ]; then
  echo "ERROR: Config file $CONF not found." >&2
  exit 1
fi

# Check if already configured
if grep -q "lxc.cgroup2.devices.allow" "$CONF"; then
  echo "TUN device already configured for LXC ${LXC_ID}."
  echo "Current config:"
  grep -E "lxc\.(cgroup2|mount\.entry)" "$CONF"
  exit 0
fi

# Add TUN device config
echo "lxc.cgroup2.devices.allow: c 10:200 rwm" >> "$CONF"
echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >> "$CONF"
echo "TUN device added to $CONF"

# Reboot the LXC for changes to take effect
echo ""
echo "Rebooting LXC ${LXC_ID}..."
pct reboot "$LXC_ID" --timeout 30
sleep 15

# Verify
echo ""
echo "=== Verifying TUN device in LXC ${LXC_ID} ==="
pct exec "$LXC_ID" -- ls -la /dev/net/tun 2>&1 || echo "LXC may not be fully started yet. Check manually."

echo ""
echo "=== TUN device setup complete for LXC ${LXC_ID} ==="
