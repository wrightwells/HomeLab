# terraform/modules/vm100-pfsense/main.tf
# Module purpose:
# VM100 pfSense firewall VM
#
# This module should contain the Proxmox resource definition for this vm.
#
# Typical contents:
# - resource "proxmox_virtual_environment_vm" "this" { ... }
# - cpu, memory, disk, network settings
# - tags and description
# - initialization / cloud-init if relevant
#
# Example skeleton:
#
# resource "proxmox_virtual_environment_vm" "this" {
#   # fill in resource details here
# }
