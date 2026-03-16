resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.target_node
  vm_id        = var.config.vmid
  description  = var.config.description
  tags         = var.config.tags
  unprivileged = var.config.unprivileged
  started      = var.config.start
  on_boot      = var.config.onboot

  initialization {
    hostname = var.config.hostname

    ip_config {
      ipv4 {
        address = var.config.ip_address
        gateway = coalesce(var.config.gateway, var.default_gateway)
      }
    }
  }

  cpu {
    cores = var.config.cores
  }

  memory {
    dedicated = var.config.memory
    swap      = var.config.swap
  }

  disk {
    datastore_id = var.default_storage
    size         = var.config.rootfs_size
  }

  network_interface {
    name   = "eth0"
    bridge = coalesce(var.config.bridge, var.default_bridge)
    vlan_id = try(var.config.vlan_id, null)
  }

  operating_system {
    template_file_id = var.config.ostemplate
    type             = "debian"
  }
}
