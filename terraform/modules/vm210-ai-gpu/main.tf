# terraform/modules/vm210-ai-gpu/main.tf
# Module purpose:
# VM210 AI GPU VM for Frigate, Home Assistant, and AI models
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
