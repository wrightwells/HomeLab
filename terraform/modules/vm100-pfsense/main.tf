terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

data "proxmox_virtual_environment_file" "pfsense_iso" {
  node_name    = var.proxmox_node
  datastore_id = var.pfsense_iso_datastore
  content_type = "iso"
  file_name    = var.pfsense_iso_file_name
}

resource "proxmox_virtual_environment_vm" "this" {
  depends_on = [data.proxmox_virtual_environment_file.pfsense_iso]
  name       = "pfsense"
  node_name  = var.proxmox_node
  vm_id      = 100
  started    = var.started
  on_boot    = var.on_boot
  tags       = ["terraform", "firewall", "pfsense"]
  boot_order = ["sata0", "scsi0"]

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = 32
    file_format  = "raw"
  }

  disk {
    file_id   = data.proxmox_virtual_environment_file.pfsense_iso.id
    interface = "sata0"
  }

  network_device {
    bridge = var.bootstrap_bridge
    model  = "virtio"
  }

  network_device {
    bridge = var.wan_bridge
    model  = "virtio"
  }

  network_device {
    bridge = var.lan_bridge
    model  = "virtio"
    trunks = var.lan_trunks
  }

  network_device {
    bridge = var.dmz_bridge
    model  = "virtio"
  }

  operating_system {
    type = "other"
  }

  agent {
    enabled = false
  }

  description = "Starter pfSense VM with bootstrap, WAN, LAN/trunk, and DMZ interfaces. Boot from the imported Netgate installer disk image and finish setup in the Proxmox console."

  lifecycle {
    prevent_destroy = true
  }
}
