terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = "ai-gpu"
  node_name = var.proxmox_node
  vm_id     = 210
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
        address = "10.10.20.210/24"
        gateway = "10.10.20.1"
      }
    }

    user_account {
      username = var.ansible_user
      keys     = var.ssh_public_key == "" ? [] : [var.ssh_public_key]
    }
  }

  network_device {
    bridge  = "vmbr1"
    vlan_id = 20
  }

  operating_system {
    type = "l26"
  }

  description = "AI VM cloned from a prepared Proxmox template. Extend with GPU passthrough as needed."
}
