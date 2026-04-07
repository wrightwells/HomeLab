#!/usr/bin/env bash

# deploy-all.sh -- Full staged deploy following the approved 10-step bootstrap flow.
#
# This script runs:
#   Step 5:  Terraform pfSense only
#   (pause for manual pfSense install -- step 6)
#   Step 8:  Terraform remaining VMs and LXCs including Mint
#   (pause for manual network move from vmbr0 to vmbr2 -- step 9)
#   Step 10: Ansible site playbook
#
# For a guided flow with explicit stop points, use:
#   ./scripts/bootstrap-from-proxmox.sh

source "$(dirname "$0")/_common.sh"

ensure_vault_file
setup_ansible_env

echo "=== Step 5: Terraform pfSense only ==="
"$ROOT_DIR/scripts/terraform-init.sh" pfsense
(cd "$TERRAFORM_DIR/environments/pfsense" && terraform validate)
"$ROOT_DIR/scripts/terraform-apply.sh" pfsense

echo ""
echo "=== PAUSE: Step 6 -- Manual pfSense install ==="
echo "pfSense VM 100 has been created."
echo "You must now:"
echo "  1. Attach the pfSense ISO to VM 100"
echo "  2. Boot and install pfSense from the Proxmox console"
echo "  3. Detach the ISO and restore boot order"
echo "  4. Complete manual pfSense GUI setup (see README-pfsense.md)"
echo "  5. Confirm vmbr1/vmbr2/vmbr3 networking is ready"
echo ""
echo "Press Enter when pfSense is installed and configured..."
read -r

echo ""
echo "=== Step 8: Terraform remaining VMs and LXCs (including Mint) ==="
"$ROOT_DIR/scripts/terraform-init.sh" production
(cd "$TERRAFORM_DIR/environments/production" && terraform validate)
"$ROOT_DIR/scripts/terraform-apply.sh" production

echo ""
echo "=== LXC post-create settings ==="
"$ROOT_DIR/scripts/proxmox-apply-lxc-postcreate.sh"

echo ""
echo "=== PAUSE: Step 9 -- Move Proxmox host IP from vmbr0 to vmbr2 ==="
echo "Update /etc/network/interfaces to move the host management IP."
echo "See README-bootstrap.md step 9 for the target configuration."
echo ""
echo "Press Enter when the network move is complete..."
read -r

echo ""
echo "=== Step 10: Ansible site deploy ==="
"$ROOT_DIR/scripts/ansible-install.sh"
(cd "$ANSIBLE_DIR" && ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml --syntax-check)
"$ROOT_DIR/scripts/ansible-ping.sh"
(cd "$ANSIBLE_DIR" && ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml)

echo ""
echo "=== Deploy complete ==="
echo "Next steps:"
echo "  - Apply pfSense config: cd ansible && ansible-playbook -i inventories/production/hosts.ini playbooks/pfsense.yml"
echo "  - Pull initial Ollama models (see README-bootstrap.md step 10.4)"
