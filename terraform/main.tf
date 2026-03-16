# terraform/main.tf
# Purpose:
# - Root Terraform entry point
# - Calls modules for all VMs and LXCs
# - Optionally renders Ansible inventory from Terraform data
#
# Typical contents:
# module "vm100_pfsense" { ... }
# module "vm210_ai_gpu" { ... }
# module "lxc066_docker_arr" { ... }
# module "lxc200_docker_services" { ... }
# module "lxc220_docker_apps" { ... }
# module "lxc230_docker_media" { ... }
# module "lxc240_docker_external" { ... }
# module "lxc250_infra" { ... }
#
# Optional:
# resource "local_file" "ansible_inventory" {
#   filename = "${path.module}/../ansible/inventories/production/hosts.yml"
#   content  = templatefile("${path.module}/templates/ansible_inventory.tftpl", {...})
# }
