resource "proxmox_virtual_environment_vm" "this" {
  name      = "pfsense"
  node_name = var.proxmox_node
  vm_id     = 100
  started   = false
  on_boot   = true
  tags      = ["terraform", "firewall", "pfsense"]

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = 32
    file_format  = "raw"
  }

  network_device {
    bridge  = var.vm_bridge
    vlan_id = var.vm_vlan
  }

  operating_system {
    type = "other"
  }

  agent {
    enabled = false
  }

  description = "Starter pfSense VM. Attach ISO and finish install in Proxmox console."
}
