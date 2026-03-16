resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.proxmox_node
  vm_id        = 240
  started      = false
  on_boot      = true
  unprivileged = true

  initialization {
    hostname = "docker-external"

    ip_config {
      ipv4 {
        address = "10.10.66.240/24"
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
    cores = 2
  }

  memory {
    dedicated = 4096
    swap      = 512
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 32
  }

  network_interface {
    name    = "eth0"
    bridge  = var.vm_bridge
    vlan_id = var.vm_vlan
  }

  features {
    nesting = true
  }

  description = "Starter LXC for docker-external"
}
