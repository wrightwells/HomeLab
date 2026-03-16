# terraform/modules/lxc200-docker-services/main.tf
# Module purpose:
# LXC200 docker-services host for Immich, Owncloud, and Syncthing
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
