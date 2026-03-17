resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.proxmox_node
  vm_id        = 200
  started      = false
  on_boot      = true
  unprivileged = true

  initialization {
    hostname = "docker-services"

    ip_config {
      ipv4 {
        address = "10.10.66.200/24"
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
    cores = 4
  }

  memory {
    dedicated = 8192
    swap      = 512
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 64
  }

  network_interface {
    name    = "eth0"
    bridge  = var.vm_bridge
    vlan_id = var.vm_vlan
  }

  features {
    nesting = true
    keyctl  = true
  }

  mount_point {
    volume = "/mnt/appdata"
    path   = "/mnt/appdata"
  }

  description = "Starter LXC for docker-services"
}
