terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_hardware_mapping_pci" "gpu" {
  count = var.gpu_pci_address != "" ? 1 : 0

  name = var.gpu_mapping_name
  map = [
    {
      id           = var.gpu_device_id
      iommu_group  = var.gpu_iommu_group
      node         = var.proxmox_node
      path         = "${var.gpu_pci_address}.0"
      subsystem_id = var.gpu_subsystem_id
    }
  ]
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.proxmox_node
  vm_id     = var.vm_id
  started   = var.started
  on_boot   = var.on_boot
  machine   = var.gpu_pci_address != "" ? "q35" : null
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

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    user_account {
      username = var.ansible_user
      password = var.bootstrap_password
      keys     = var.ssh_public_keys
    }
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
    model   = "virtio"
  }

  operating_system {
    type = "l26"
  }

  dynamic "hostpci" {
    for_each = var.gpu_pci_address != "" ? [var.gpu_pci_address] : []
    content {
      device  = "hostpci0"
      mapping = proxmox_virtual_environment_hardware_mapping_pci.gpu[0].name
      pcie    = true
      rombar  = true
      xvga    = true
    }
  }

  description = "AI VM cloned from a prepared Proxmox template. Extend with GPU passthrough as needed."
}
