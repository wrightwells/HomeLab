resource "proxmox_virtual_environment_vm" "this" {
  node_name   = var.target_node
  vm_id       = var.config.vmid
  name        = var.config.name
  description = var.config.description
  tags        = var.config.tags
  on_boot     = var.config.onboot
  started     = var.config.start_on_boot

  agent {
    enabled = var.config.agent
  }

  cpu {
    cores   = var.config.cores
    sockets = var.config.sockets
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.config.memory
  }

  network_device {
    bridge  = coalesce(var.config.bridge, var.default_bridge)
    model   = "virtio"
    vlan_id = try(var.config.vlan_id, null)
  }

  disk {
    datastore_id = var.default_storage
    interface    = "scsi0"
    size         = var.config.disk_size_gb
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  dynamic "clone" {
    for_each = try(var.config.clone, null) != null ? [var.config.clone] : []
    content {
      vm_id = 0
    }
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.config.ip_address
        gateway = coalesce(var.config.gateway, var.default_gateway)
      }
    }
  }
}
