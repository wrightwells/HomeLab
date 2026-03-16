# terraform/modules/lxc066-docker-arr/main.tf
# Module purpose:
# LXC066 docker-arr host for Filebrowser, Jellyseerr, Aurral, and arr stack
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
