# terraform/modules/lxc240-docker-external/main.tf
# Module purpose:
# LXC240 docker-external host for NGINX, Tailscale relay, Jellyswarm, Ghost, DNNS, Kutt, WordPress, and Walletpage
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
