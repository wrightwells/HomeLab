terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.proxmox_node
  vm_id     = var.vm_id
  started   = var.started
  on_boot   = var.on_boot
  tags      = ["terraform", "ai", "gpu", "docker"]

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  agent {
    enabled = true
  }

  clone {
    vm_id = var.clone_vmid
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = 128
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.cloudinit_storage

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    user_account {
      username = var.ansible_user
      keys     = var.ssh_public_key == "" ? [] : [var.ssh_public_key]
    }
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  operating_system {
    type = "l26"
  }

  hostpci {
    device = "hostpci0"
    id     = var.gpu_pci_address
    pcie   = true
    rombar = true
    x_vga  = true
  }

  description = "AI VM cloned from a prepared Proxmox template. Extend with GPU passthrough as needed."
}
