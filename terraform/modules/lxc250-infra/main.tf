# terraform/modules/lxc250-infra/main.tf
# Module purpose:
# LXC250 infra host for MQTT, Homebridge, and NGINX
#
# This module should contain the Proxmox resource definition for this container.
#
# Typical contents:
# - resource "proxmox_virtual_environment_container" "this" { ... }
# - cpu, memory, disk, network settings
# - tags and description
# - initialization / cloud-init if relevant
#
# Example skeleton:
#
# resource "proxmox_virtual_environment_container" "this" {
#   # fill in resource details here
# }
