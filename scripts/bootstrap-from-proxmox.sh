#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/_common.sh"

pause() {
  local message="$1"
  printf '\n%s\n' "$message"
  read -r -p "Press Enter to continue..."
}

run_step() {
  local message="$1"
  shift
  printf '\n== %s ==\n' "$message"
  "$@"
}

cat <<'EOF'
Guided HomeLab bootstrap from the Proxmox host.

This script follows the approved 11-step bootstrap flow with manual checkpoints:

  1. Proxmox install and base host preparation        [done before this script]
  2. /etc/network/interfaces on vmbr0                  [done before this script]
  3. Disk creation / storage preparation               [prompted below]
  4. Tailscale on host, verify SSH over Tailscale      [prompted below]
  5. Terraform pfSense only                            [automated below]
  6. Install and configure pfSense manually            [pause for manual work]
  7. Create SSH keypair, publish bootstrap to /mnt/appdata [done before this script]
  8. Terraform remaining VMs/LXCs (including Mint)     [automated below]
  9. Run SSH bootstrap on each created machine         [pause for manual work]
 10. Move Proxmox host IP from vmbr0 to vmbr2          [pause for manual work]
 11. Run Ansible to build/configure VMs and LXCs       [automated below]

Do not run the same staged Terraform commands from the README unless you
are intentionally re-running a specific step.
EOF

pause "Before continuing, make sure:
- ansible/inventories/production/group_vars/proxmox.yml has the correct disk by-id values
- terraform/terraform.tfvars has the correct API token, node, resource profile, template VMIDs, LXC root password, and SSH public key
- the Debian 12 LXC template is already downloaded on this Proxmox host
- the Linux Mint and Ubuntu cloud-image templates are prepared
- you have published the bootstrap bundle: ./scripts/publish-control-node-bootstrap.sh"

ensure_vault_file
setup_ansible_env

run_step "Install Ansible collections" "$ROOT_DIR/scripts/ansible-install.sh"

pause "If this is the first storage bootstrap, run the Proxmox storage playbook in another shell:
  cd $ANSIBLE_DIR
  ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-storage.yml
Come back here after storage is prepared and /mnt/appdata exists."

pause "If you want Tailscale on the Proxmox host, run this in another shell:
  cd $ANSIBLE_DIR
  ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-host.yml
Verify SSH access over Tailscale before continuing."

run_step "Terraform init for pfSense stage" "$ROOT_DIR/scripts/terraform-init.sh" pfsense
run_step "Terraform validate for pfSense stage" terraform -chdir="$TERRAFORM_DIR/environments/pfsense" validate
run_step "Terraform plan for pfSense stage" "$ROOT_DIR/scripts/terraform-plan.sh" pfsense

pause "Phase 1 provisions pfSense ONLY (VM 100).
After apply, attach the pfSense ISO to VM 100, install pfSense manually in the Proxmox console, and complete the initial WAN/LAN/DMZ setup."

run_step "Terraform apply for pfSense stage" "$ROOT_DIR/scripts/terraform-apply.sh" pfsense

pause "Complete the manual pfSense work now:
- attach the pfSense ISO to VM 100
- boot and install pfSense
- detach the ISO and restore boot order to scsi0
- finish the manual prerequisites in README-pfsense.md
- confirm vmbr1/vmbr2/vmbr3 and pfSense networking are ready
Return here only after pfSense is installed."

run_step "Terraform init for production stage" "$ROOT_DIR/scripts/terraform-init.sh" production
run_step "Terraform validate for production stage" terraform -chdir="$TERRAFORM_DIR/environments/production" validate
run_step "Terraform plan for production stage" "$ROOT_DIR/scripts/terraform-plan.sh" production

pause "Phase 2 provisions Mint plus all remaining VMs and LXCs."

run_step "Terraform apply for production stage" "$ROOT_DIR/scripts/terraform-apply.sh" production

pause "Terraform has created all guests. Apply the Proxmox root-only LXC options next."

run_step "Apply LXC post-create settings" "$ROOT_DIR/scripts/proxmox-apply-lxc-postcreate.sh"

pause "Step 9: Run the SSH bootstrap script on each created machine.
For LXCs: log in as root (vault password) then run:
  /mnt/appdata/homelab-control/bin/bootstrap-control-node.sh
For VMs (Mint, AI GPU):
  /mnt/appdata/homelab-control/bin/bootstrap-user-control-node.sh"

pause "Step 10: Move the Proxmox host management IP from vmbr0 to vmbr2.
Update /etc/network/interfaces. See README-bootstrap.md step 10."

run_step "Ansible ping" "$ROOT_DIR/scripts/ansible-ping.sh"

pause "Review the generated inventory and verify SSH access to all guests.
When ready, the next command runs the main Ansible site playbook."

run_step "Ansible site deploy" bash -lc "cd '$ANSIBLE_DIR' && ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml"

pause "When the Linux hosts are configured, continue with the dedicated pfSense playbook:
  cd $ANSIBLE_DIR
  ansible-playbook -i inventories/production/hosts.ini playbooks/pfsense.yml
Then return to README-bootstrap.md for the remaining service-specific steps."

printf '\nBootstrap flow complete.\n'
