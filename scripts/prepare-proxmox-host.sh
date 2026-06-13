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
HOST_CONTROL_KEY="${HOST_CONTROL_KEY:-$HOME/.ssh/homelab-bootstrap}"
HOST_CONTROL_TFVARS_FILE="${HOST_CONTROL_TFVARS_FILE:-$REPO_DIR/terraform/generated/proxmox-host-control.auto.tfvars.json}"

VAULT_PASSWORD="${1:-}"

# ---------------------------------------------------------------------------
# 1.1 Configure no-subscription repositories
# ---------------------------------------------------------------------------
echo "=== Configuring Proxmox no-subscription repositories ==="
PVE_SUITE="$(. /etc/os-release && echo "${VERSION_CODENAME}")"

if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
  sed -i 's/^deb/#deb/g' /etc/apt/sources.list.d/pve-enterprise.list
  echo "Disabled pve-enterprise.list"
fi

if [ -f /etc/apt/sources.list.d/pve-enterprise.sources ]; then
  mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled
  echo "Disabled pve-enterprise.sources"
fi

if [ -f /etc/apt/sources.list.d/ceph.sources ]; then
  mv /etc/apt/sources.list.d/ceph.sources /etc/apt/sources.list.d/ceph.sources.disabled
  echo "Disabled ceph.sources"
fi

rm -f /etc/apt/sources.list.d/pve-no-sub.list

cat > /etc/apt/sources.list.d/pve-no-subscription.sources <<EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: ${PVE_SUITE}
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
echo "Enabled pve-no-subscription (${PVE_SUITE})"

cat > /etc/apt/sources.list.d/ceph-no-subscription.sources <<EOF
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: ${PVE_SUITE}
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
echo "Enabled ceph-squid no-subscription (${PVE_SUITE})"

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
  software-properties-common python3-pip ansible sshpass

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
# 1.6 Install Ansible collections
# ---------------------------------------------------------------------------
echo ""
echo "=== Installing Ansible collections ==="
if [ -f "$REPO_DIR/ansible/requirements.yml" ]; then
  (cd "$REPO_DIR/ansible" && ansible-galaxy collection install -r requirements.yml)
else
  echo "Skipping collections install because $REPO_DIR/ansible/requirements.yml is missing"
fi

# ---------------------------------------------------------------------------
# 1.7 Verify tools
# ---------------------------------------------------------------------------
echo ""
echo "=== Verifying tools ==="
git --version
ansible --version | head -1
terraform version | head -1

# ---------------------------------------------------------------------------
# 1.8 Set up Ansible vault password file
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
# 1.9 Create SSH keypairs and publish them
# ---------------------------------------------------------------------------
echo ""
echo "=== Setting up SSH keys ==="
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -C "homelab-deploy" -f ~/.ssh/id_ed25519 -N ""
  echo "SSH keypair generated"
fi

if [ ! -f "$HOST_CONTROL_KEY" ]; then
  ssh-keygen -t ed25519 -C "homelab-proxmox-control" -f "$HOST_CONTROL_KEY" -N ""
  echo "Host-local guest access key generated"
fi

mkdir -p "$(dirname "$HOST_CONTROL_TFVARS_FILE")"
jq -Rn --arg key "$(cat "${HOST_CONTROL_KEY}.pub")" \
  '{
    ssh_public_key: $key,
    host_control_ssh_public_key: $key
  }' > "$HOST_CONTROL_TFVARS_FILE"
chmod 600 "$HOST_CONTROL_TFVARS_FILE"
echo "Wrote Terraform host-control key vars to $HOST_CONTROL_TFVARS_FILE"

echo ""
echo "Add this public key as a deploy key on your GitHub repo:"
cat ~/.ssh/id_ed25519.pub
echo ""
read -rp "Press Enter after the deploy key is added to GitHub..."

# ---------------------------------------------------------------------------
# 1.10 Fix hostname for Proxmox cluster (pvecm/pct rely on correct hostname)
# ---------------------------------------------------------------------------
echo ""
echo "=== Fixing Proxmox hostname for cluster tools ==="
EXPECTED_HOSTNAME="pve"
EXPECTED_SHORT="pve"
MANAGEMENT_IP="10.10.99.110"

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

# Remove any stale entries for old Proxmox node names
sed -i '/pve01/d' /etc/hosts
sed -i '/pve\.uk\.wrightwells\.com/d' /etc/hosts
sed -i '/vm050-mint/d' /etc/hosts

# Add the correct entry with the management IP
echo "${MANAGEMENT_IP} ${EXPECTED_SHORT}" >> /etc/hosts
echo "Added ${EXPECTED_SHORT} -> ${MANAGEMENT_IP} to /etc/hosts"

# ---------------------------------------------------------------------------
# 1.11 Publish control node bootstrap scripts
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
echo "  4. Keep $HOST_CONTROL_TFVARS_FILE alongside terraform/terraform.tfvars for guest SSH access from the Proxmox host"
