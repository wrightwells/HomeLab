terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.proxmox_node
  vm_id         = 166
  started       = var.started
  start_on_boot = var.start_on_boot
  unprivileged  = true

  initialization {
    hostname = "docker-arr"

    ip_config {
      ipv4 {
        address = "10.10.66.66/24"
        gateway = "10.10.66.1"
      }
    }

    user_account {
      password = "change-me-now"
      keys     = var.ssh_public_key == "" ? [] : [var.ssh_public_key]
    }
  }

  operating_system {
    template_file_id = var.debian_lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 32
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr2"
  }

  features {
    nesting = true
    keyctl  = true
  }

  mount_point {
    volume = "/mnt/appdata"
    path   = "/mnt/appdata"
  }
  mount_point {
    volume = "/mnt/media_pool"
    path   = "/mnt/media_pool"
  }

  description = "Starter LXC for docker-arr"
}
