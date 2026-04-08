#!/usr/bin/env bash
# prepare-templates.sh -- Step 2: Prepare Proxmox templates before Terraform.
#
# Downloads the Debian 12 LXC template and verifies that the VM templates
# (Linux Mint Cinnamon and Ubuntu 24.04 cloud-image) are available.
#
# Usage: ./scripts/prepare-templates.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# 2.1 Download Debian 12 LXC template
# ---------------------------------------------------------------------------
echo "=== Downloading Debian 12 LXC template ==="
pveam update

TEMPLATE=$(pveam available | awk '/debian-12-standard/ {print $2; exit}')
if [ -z "$TEMPLATE" ]; then
  echo "ERROR: No Debian 12 standard template found." >&2
  exit 1
fi

echo "Found template: $TEMPLATE"
pveam download local "$TEMPLATE"
echo "Template downloaded."

# ---------------------------------------------------------------------------
# 2.2 Verify VM templates
# ---------------------------------------------------------------------------
echo ""
echo "=== Verifying VM templates ==="

# Check for the AI VM template (Ubuntu 24.04 cloud-image, VMID 9000)
if qm config 9000 &>/dev/null; then
  echo "VM 9000 (Ubuntu 24.04 AI template) exists."
else
  echo "WARNING: VM 9000 (Ubuntu 24.04 AI template) not found."
  echo "Create it with the commands in README-bootstrap.md, then set vm_template_vmid=9000 in terraform.tfvars."
fi

# Check for the Mint template (VMID 9050)
if qm config 9050 &>/dev/null; then
  echo "VM 9050 (Linux Mint template) exists."
else
  echo "WARNING: VM 9050 (Linux Mint template) not found."
  echo "Create it with the commands in README-bootstrap.md, then set vm050_mint_template_vmid=9050 in terraform.tfvars."
fi

echo ""
echo "=== Template preparation complete ==="
