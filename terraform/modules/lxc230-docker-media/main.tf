# terraform/modules/lxc230-docker-media/main.tf
# Module purpose:
# LXC230 docker-media host for Plex and Jellyfin
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
