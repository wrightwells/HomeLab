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

This script intentionally stops at the manual checkpoints that still require
human input:
- storage disk mapping review
- Terraform variable review
- pfSense ISO install and first boot setup
- Linux Mint template verification
- optional GPU passthrough prep

This guided script is the scripted alternative to the manual Terraform flow in
README-bootstrap.md sections 10 through 15. While following this script, do not
separately run the same staged Terraform commands from the README unless you
are intentionally re-running a specific step.
EOF

pause "Before continuing, review README-bootstrap.md sections 7-9 and make sure:
- ansible/inventories/production/group_vars/proxmox.yml has the correct disk by-id values
- terraform/terraform.tfvars has the correct API token, node, resource profile, template VMIDs, GPU PCI address, LXC template, and SSH public key
- the Debian 12 LXC template referenced by terraform.tfvars is already downloaded on this Proxmox host"

ensure_vault_file
setup_ansible_env

run_step "Install Ansible collections" "$ROOT_DIR/scripts/ansible-install.sh"

pause "If this is the first storage bootstrap, run the Proxmox storage playbook in another shell when ready:
  cd $ANSIBLE_DIR
  ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-storage.yml
Come back here after storage is prepared and the host paths under /mnt/appdata and /mnt/media_pool exist."

pause "If you want Tailscale on the Proxmox host, run this in another shell before Terraform:
  cd $ANSIBLE_DIR
  ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-host.yml
Come back when the host-side prerequisites are done."

run_step "Terraform init for pfSense stage" "$ROOT_DIR/scripts/terraform-init.sh" pfsense
run_step "Terraform validate for pfSense stage" terraform -chdir="$TERRAFORM_DIR/environments/pfsense" validate
run_step "Terraform plan for pfSense stage" "$ROOT_DIR/scripts/terraform-plan.sh" pfsense

pause "Phase 1 provisions pfSense and the Linux Mint VM.
The next command applies the dedicated pfSense Terraform environment, which now also creates the Mint desktop VM on VMID 150 required to access the pfSense UI.
After it completes, attach the pfSense ISO to VM 100, install pfSense manually in the Proxmox console, and complete the initial WAN/LAN/DMZ setup before continuing."

run_step "Terraform apply for pfSense stage" "$ROOT_DIR/scripts/terraform-apply.sh" pfsense

pause "Complete the manual pfSense work now:
- attach the pfSense ISO to VM 100
- boot and install pfSense
- detach the ISO and restore boot order
- finish the manual prerequisites in README-pfsense.md
- confirm vmbr1/vmbr2/vmbr3 and pfSense networking are in the state you want
Return here only after pfSense is installed and the network design is ready for the rest of the lab."

run_step "Terraform init for production stage" "$ROOT_DIR/scripts/terraform-init.sh" production
run_step "Terraform validate for production stage" terraform -chdir="$TERRAFORM_DIR/environments/production" validate
run_step "Terraform plan for the remaining stack" "$ROOT_DIR/scripts/terraform-plan.sh" production
run_step "Terraform apply for the remaining stack" "$ROOT_DIR/scripts/terraform-apply.sh" production

pause "Terraform has now created the remaining guests. Apply the Proxmox root-only LXC options next."

run_step "Apply LXC post-create settings" "$ROOT_DIR/scripts/proxmox-apply-lxc-postcreate.sh"

run_step "Ansible ping" "$ROOT_DIR/scripts/ansible-ping.sh"

pause "Review the generated inventory and verify SSH access to the guests.
When ready, the next command runs the main Ansible site playbook."

run_step "Ansible site deploy" bash -lc "cd '$ANSIBLE_DIR' && ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml"

pause "When the Linux hosts are configured, continue with the dedicated pfSense playbook if needed:
  cd $ANSIBLE_DIR
  ansible-playbook -i inventories/production/hosts.ini playbooks/pfsense.yml
Then return to README-bootstrap.md for the remaining service-specific steps."

printf '\nBootstrap flow complete.\n'
