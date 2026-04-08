#!/usr/bin/env bash
# move-proxmox-ip.sh -- Step 9: Move Proxmox management IP from vmbr0 to vmbr2.99.
#
# This script moves the Proxmox host management IP from the bootstrap bridge
# (vmbr0, 10.10.1.10) to the management VLAN behind pfSense (vmbr2.99, 10.10.99.10).
#
# IMPORTANT: After running this script, your SSH session will disconnect.
# Reconnect using the new IP: ssh root@10.10.99.10
#
# Use the Proxmox console or Tailscale as a fallback if the move fails.
#
# Usage: ./scripts/move-proxmox-ip.sh

set -euo pipefail

INTERFACES_FILE="/etc/network/interfaces"
NEW_IP="10.10.99.10/24"
NEW_GW="10.10.99.1"
HOSTNAME_SHORT=$(hostname -s 2>/dev/null || echo "pve01")
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || echo "${HOSTNAME_SHORT}.uk.wrightwells.com")

echo "=== Moving Proxmox management IP to vmbr2.99 ==="
echo "Current IP: $(ip -4 addr show vmbr0 2>/dev/null | grep -oP 'inet \K[0-9.]+') (vmbr0)"
echo "New IP:     ${NEW_IP} (vmbr2.99, gateway ${NEW_GW})"
echo ""
echo "WARNING: Your SSH session will disconnect after this change."
echo "Reconnect to the new IP: ssh root@10.10.99.10"
echo "Use the Proxmox console or Tailscale as fallback if needed."
echo ""
read -rp "Press Enter to proceed, or Ctrl+C to cancel..."

# ---------------------------------------------------------------------------
# Update /etc/network/interfaces
# ---------------------------------------------------------------------------
echo ""
echo "=== Updating /etc/network/interfaces ==="

# Backup current interfaces
cp "$INTERFACES_FILE" "${INTERFACES_FILE}.bak.$(date +%Y%m%d%H%M%S)"

# Write the new interfaces file
cat > "$INTERFACES_FILE" <<'INTERFACES'
# Loopback
auto lo
iface lo inet loopback

# Physical NICs
auto nic0
iface nic0 inet manual

auto nic1
iface nic1 inet manual

auto nic2
iface nic2 inet manual

# Bootstrap / temporary access bridge on nic0
# Kept defined but no longer carries the host IP.
auto vmbr0
iface vmbr0 inet static
    address 10.10.1.10/24
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0

# pfSense WAN bridge on nic1
auto vmbr1
iface vmbr1 inet manual
    bridge-ports nic1
    bridge-stp off
    bridge-fd 0

# pfSense LAN trunk on nic2
auto vmbr2
iface vmbr2 inet manual
    bridge-ports nic2
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# Proxmox host management on VLAN 99 behind pfSense
auto vmbr2.99
iface vmbr2.99 inet static
    address 10.10.99.10/24
    gateway 10.10.99.1

# Optional DMZ / untrusted bridge
auto vmbr3
iface vmbr3 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
INTERFACES

echo "Network interfaces updated."

# ---------------------------------------------------------------------------
# Fix hostname resolution for pvecm/pct after network change
# ---------------------------------------------------------------------------
if grep -q "$HOSTNAME_SHORT" /etc/hosts; then
  sed -i "/${HOSTNAME_SHORT}/d" /etc/hosts
fi
echo "10.10.99.10 ${HOSTNAME_FQDN} ${HOSTNAME_SHORT}" >> /etc/hosts
echo "Updated hostname entry to point to management VLAN IP (10.10.99.10)"

# ---------------------------------------------------------------------------
# Apply the network change
# ---------------------------------------------------------------------------
echo ""
echo "=== Applying network change ==="
echo "This will disconnect your SSH session. Reconnect to 10.10.99.10."

# Bring up the new interface and bring down the old IP
ifup vmbr2.99 2>/dev/null || true
sleep 2
ip addr del 10.10.1.10/24 dev vmbr0 2>/dev/null || true

echo ""
echo "=== IP migration complete ==="
echo "If you can still reach the host, verify with: ip -br addr show vmbr2.99"
echo "If disconnected, reconnect: ssh root@10.10.99.10"
