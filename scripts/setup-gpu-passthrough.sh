#!/usr/bin/env bash
# setup-gpu-passthrough.sh -- Enable IOMMU, VFIO, and bind GPU for passthrough.
#
# This script runs on the Proxmox host and:
#   1. Discovers the GPU PCI address
#   2. Enables IOMMU in GRUB
#   3. Loads VFIO modules
#   4. Binds the GPU to VFIO
#   5. Updates initramfs
#
# After running, reboot the host, then configure the VM with:
#   qm set VMID --hostpci0 '0000:06:00,pcie=1,rombar=1,x-vga=1'
#   qm set VMID --machine q35
#
# Usage: ./scripts/setup-gpu-passthrough.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Discover GPU
# ---------------------------------------------------------------------------
echo "=== Discovering GPU ==="
GPU_LINE=$(lspci -nn | grep -iE 'vga.*nvidia|nvidia.*vga' | head -1)
if [ -z "$GPU_LINE" ]; then
  echo "ERROR: No NVIDIA GPU found." >&2
  exit 1
fi

GPU_ADDR=$(echo "$GPU_LINE" | awk '{print $1}')
GPU_IDS=$(echo "$GPU_LINE" | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}' | head -2 | tr '\n' ',' | sed 's/,$//')

# Also grab the audio function if present
AUDIO_LINE=$(lspci -nn | grep -iE 'audio.*nvidia|nvidia.*audio' | head -1)
if [ -n "$AUDIO_LINE" ]; then
  AUDIO_ADDR=$(echo "$AUDIO_LINE" | awk '{print $1}')
  AUDIO_IDS=$(echo "$AUDIO_LINE" | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}')
  ALL_IDS="${GPU_IDS},${AUDIO_IDS}"
else
  ALL_IDS="$GPU_IDS"
fi

echo "GPU: $GPU_ADDR ($GPU_IDS)"
[ -n "${AUDIO_ADDR:-}" ] && echo "Audio: $AUDIO_ADDR ($AUDIO_IDS)"
PCI_SHORT=$(echo "$GPU_ADDR" | sed 's/\.[0-9]$//')
PCI_FULL="0000:${PCI_SHORT}"

echo "Proxmox PCI form: $PCI_FULL"

# ---------------------------------------------------------------------------
# Enable IOMMU in GRUB
# ---------------------------------------------------------------------------
echo ""
echo "=== Enabling IOMMU in GRUB ==="
if ! grep -q "intel_iommu=on" /etc/default/grub; then
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt /' /etc/default/grub
  update-grub
  echo "IOMMU enabled."
else
  echo "IOMMU already enabled."
fi

# ---------------------------------------------------------------------------
# Load VFIO modules
# ---------------------------------------------------------------------------
echo ""
echo "=== Configuring VFIO modules ==="
for mod in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
  if ! grep -q "^${mod}$" /etc/modules 2>/dev/null; then
    echo "$mod" >> /etc/modules
    echo "Added $mod to /etc/modules"
  fi
done

# ---------------------------------------------------------------------------
# VFIO modprobe config
# ---------------------------------------------------------------------------
echo ""
echo "=== Creating VFIO modprobe config ==="
cat > /etc/modprobe.d/vfio.conf <<EOF
options vfio-pci ids=${ALL_IDS}
softdep nvidia pre: vfio-pci
softdep nouveau pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
EOF
echo "Created /etc/modprobe.d/vfio.conf with GPU IDs: ${ALL_IDS}"

# ---------------------------------------------------------------------------
# Update initramfs
# ---------------------------------------------------------------------------
echo ""
echo "=== Updating initramfs ==="
update-initramfs -u -k all
echo "initramfs updated."

# ---------------------------------------------------------------------------
# Load VFIO now (before reboot)
# ---------------------------------------------------------------------------
echo ""
echo "=== Loading VFIO modules ==="
modprobe vfio 2>/dev/null || true
modprobe vfio_iommu_type1 2>/dev/null || true
modprobe vfio_pci 2>/dev/null || true
modprobe vfio_virqfd 2>/dev/null || true
echo "VFIO modules loaded."

# ---------------------------------------------------------------------------
# Bind GPU to VFIO now
# ---------------------------------------------------------------------------
echo ""
echo "=== Binding GPU to VFIO ==="
echo "$PCI_FULL.0" > "/sys/bus/pci/devices/${PCI_FULL}.0/driver/unbind" 2>/dev/null || true
echo "$PCI_FULL.1" > "/sys/bus/pci/devices/${PCI_FULL}.1/driver/unbind" 2>/dev/null || true
echo "${GPU_IDS%%,*}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
echo "${GPU_IDS##*,}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
echo "GPU bound to vfio-pci."

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== GPU passthrough setup complete ==="
echo ""
echo "GPU PCI address: $PCI_FULL"
echo ""
echo "Next steps:"
echo "  1. Update terraform/terraform.tfvars:"
echo "     vm210_gpu_pci_address = \"${PCI_FULL}\""
echo "  2. Reboot the Proxmox host"
echo "  3. After reboot, configure the AI VM:"
echo "     qm set 210 --hostpci0 '${PCI_FULL},pcie=1,rombar=1,x-vga=1'"
echo "     qm set 210 --machine q35"
echo "  4. Start the AI VM and install NVIDIA drivers inside it"
