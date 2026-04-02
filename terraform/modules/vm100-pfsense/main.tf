terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = "pfsense"
  node_name = var.proxmox_node
  vm_id     = 100
  started   = var.started
  on_boot   = var.on_boot
  tags      = ["terraform", "firewall", "pfsense"]

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

  description = "Starter pfSense VM with bootstrap, WAN, LAN/trunk, and DMZ interfaces. Attach ISO and finish install in Proxmox console."
}
