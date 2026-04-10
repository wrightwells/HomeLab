#!/usr/bin/env bash
# prepare-proxmox-host.sh -- Step 1: Proxmox host preparation after initial install.
#
# This script runs on a freshly installed Proxmox host and:
#   - Configures no-subscription repositories
#   - Installs required packages (git, ansible, terraform, etc.)
#   - Clones the HomeLab repo
#   - Sets up the Ansible vault password file
#   - Publishes the SSH key and disables password auth
#
# Usage: ./scripts/prepare-proxmox-host.sh [VAULT_PASSWORD]
# If VAULT_PASSWORD is not provided, you will be prompted for it.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/wrightwells/HomeLab.git}"
REPO_DIR="${HOME}/HomeLab"
VAULT_FILE="${HOME}/.config/ansible/homelab-vault-pass.txt"

VAULT_PASSWORD="${1:-}"

# ---------------------------------------------------------------------------
# 1.1 Configure no-subscription repositories
# ---------------------------------------------------------------------------
echo "=== Configuring Proxmox no-subscription repositories ==="
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
  sed -i 's/^deb/#deb/g' /etc/apt/sources.list.d/pve-enterprise.list
  echo "Disabled pve-enterprise.list"
fi

if [ ! -f /etc/apt/sources.list.d/pve-no-sub.list ]; then
  echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-sub.list
  echo "Enabled pve-no-subscription"
fi

# ---------------------------------------------------------------------------
# 1.2 Upgrade packages
# ---------------------------------------------------------------------------
echo ""
echo "=== Upgrading packages ==="
apt update
apt full-upgrade -y

# ---------------------------------------------------------------------------
# 1.3 Install required packages
# ---------------------------------------------------------------------------
echo ""
echo "=== Installing required packages ==="
apt install -y \
  wget jq unzip pciutils lsblk git curl gnupg \
  software-properties-common python3-pip ansible

# ---------------------------------------------------------------------------
# 1.4 Install Terraform
# ---------------------------------------------------------------------------
echo ""
echo "=== Installing Terraform ==="
if ! command -v terraform &>/dev/null; then
  wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo ${VERSION_CODENAME}) main" | tee /etc/apt/sources.list.d/hashicorp.list
  apt update
  apt install -y terraform
else
  echo "Terraform already installed: $(terraform version | head -1)"
fi

# ---------------------------------------------------------------------------
# 1.5 Clone the HomeLab repo
# ---------------------------------------------------------------------------
echo ""
echo "=== Cloning HomeLab repo ==="
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
  echo "Repo cloned to $REPO_DIR"
else
  echo "Repo already exists at $REPO_DIR"
fi

# ---------------------------------------------------------------------------
# 1.6 Verify tools
# ---------------------------------------------------------------------------
echo ""
echo "=== Verifying tools ==="
git --version
ansible --version | head -1
terraform version | head -1

# ---------------------------------------------------------------------------
# 1.7 Set up Ansible vault password file
# ---------------------------------------------------------------------------
echo ""
echo "=== Setting up Ansible vault password file ==="

if [ -z "$VAULT_PASSWORD" ]; then
  read -rs -p "Enter vault password (used for Ansible vault and LXC root passwords): " VAULT_PASSWORD
  echo ""
fi

mkdir -p "$(dirname "$VAULT_FILE")"
printf '%s\n' "$VAULT_PASSWORD" > "$VAULT_FILE"
chmod 600 "$VAULT_FILE"
echo "Vault password file created at $VAULT_FILE"

# ---------------------------------------------------------------------------
# 1.8 Create SSH keypair and publish it
# ---------------------------------------------------------------------------
echo ""
echo "=== Setting up SSH deploy key ==="
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -C "homelab-deploy" -f ~/.ssh/id_ed25519 -N ""
  echo "SSH keypair generated"
fi

echo ""
echo "Add this public key as a deploy key on your GitHub repo:"
cat ~/.ssh/id_ed25519.pub
echo ""
read -rp "Press Enter after the deploy key is added to GitHub..."

# ---------------------------------------------------------------------------
# 1.9 Fix hostname for Proxmox cluster (pvecm/pct rely on correct hostname)
# ---------------------------------------------------------------------------
echo ""
echo "=== Fixing Proxmox hostname for cluster tools ==="
EXPECTED_HOSTNAME="pve01.uk.wrightwells.com"
EXPECTED_SHORT="pve01"
MANAGEMENT_IP="10.10.99.10"

# Fix /etc/hostname
if [ "$(cat /etc/hostname 2>/dev/null)" != "${EXPECTED_HOSTNAME}" ]; then
  echo "Fixing /etc/hostname from '$(cat /etc/hostname 2>/dev/null || echo "(empty)")' to '${EXPECTED_HOSTNAME}'"
  echo "${EXPECTED_HOSTNAME}" > /etc/hostname
else
  echo "/etc/hostname is already correct"
fi

# Set the live hostname
hostnamectl set-hostname "${EXPECTED_HOSTNAME}"
echo "Live hostname set to '${EXPECTED_HOSTNAME}'"

# Remove any stale entries for pve01 or old hostnames
sed -i '/pve01/d' /etc/hosts
sed -i '/vm050-mint/d' /etc/hosts

# Add the correct entry with the management IP
echo "${MANAGEMENT_IP} ${EXPECTED_HOSTNAME} ${EXPECTED_SHORT}" >> /etc/hosts
echo "Added ${EXPECTED_SHORT} -> ${MANAGEMENT_IP} to /etc/hosts"

# ---------------------------------------------------------------------------
# 1.10 Publish control node bootstrap scripts
# ---------------------------------------------------------------------------
echo ""
echo "=== Publishing bootstrap scripts to /mnt/appdata ==="
cd "$REPO_DIR"
./scripts/publish-control-node-bootstrap.sh

echo ""
echo "=== Proxmox host preparation complete ==="
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/prepare-templates.sh  (prepare VM/LXC templates)"
echo "  2. Configure terraform/terraform.tfvars  (API token, node name, template VMIDs)"
echo "  3. Run: ./scripts/terraform-init.sh pfsense && ./scripts/terraform-apply.sh pfsense"
