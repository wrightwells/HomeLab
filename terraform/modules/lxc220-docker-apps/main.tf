# terraform/modules/lxc220-docker-apps/main.tf
# Module purpose:
# LXC220 docker-apps host for Grafana, InfluxDB, Node-RED, Teslamate, Homebridge, Calibre, Calibre-Web, Grist, Blinko, and finance apps
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
