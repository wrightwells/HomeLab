#!/usr/bin/env bash
# setup-tun-device.sh -- Add /dev/net/tun to one or more LXCs.
#
# Unprivileged LXCs don't have this device by default. This script adds the
# necessary config to the target LXC config file and reboots each updated CT.
#
# Usage:
#   ./scripts/setup-tun-device.sh
#   ./scripts/setup-tun-device.sh 166
#   ./scripts/setup-tun-device.sh 200 220 230 240 250
#
# Default LXC_ID: 166

set -euo pipefail

LXC_IDS=("$@")
if [ "${#LXC_IDS[@]}" -eq 0 ]; then
  LXC_IDS=(166)
fi

ensure_tun_for_lxc() {
  local lxc_id="$1"
  local conf="/etc/pve/lxc/${lxc_id}.conf"

  echo "=== Adding /dev/net/tun to LXC ${lxc_id} ==="

  if [ ! -f "$conf" ]; then
    echo "ERROR: Config file $conf not found." >&2
    return 1
  fi

  if grep -q "^lxc.cgroup2.devices.allow: c 10:200 rwm$" "$conf" && \
     grep -q "^lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file$" "$conf"; then
    echo "TUN device already configured for LXC ${lxc_id}."
  else
    grep -q "^lxc.cgroup2.devices.allow: c 10:200 rwm$" "$conf" \
      || echo "lxc.cgroup2.devices.allow: c 10:200 rwm" >> "$conf"
    grep -q "^lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file$" "$conf" \
      || echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >> "$conf"
    echo "TUN device added to $conf"
  fi

  echo ""
  echo "Rebooting LXC ${lxc_id}..."
  pct reboot "$lxc_id" --timeout 30
  sleep 15

  echo ""
  echo "=== Verifying TUN device in LXC ${lxc_id} ==="
  pct exec "$lxc_id" -- ls -la /dev/net/tun 2>&1 || echo "LXC may not be fully started yet. Check manually."

  echo ""
  echo "=== TUN device setup complete for LXC ${lxc_id} ==="
}

for lxc_id in "${LXC_IDS[@]}"; do
  ensure_tun_for_lxc "$lxc_id"
done
