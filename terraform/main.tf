locals {
  lxc_inventory = {
    for name, cfg in var.lxc_definitions : name => {
      hostname = cfg.hostname
      ansible_host = split("/", cfg.ip_address)[0]
      ansible_user = "root"
      node         = var.target_node
      type         = "lxc"
      groups       = cfg.ansible_groups
    }
  }

  vm_inventory = {
    for name, cfg in var.vm_definitions : name => {
      hostname = cfg.name
      ansible_host = split("/", cfg.ip_address)[0]
      ansible_user = "root"
      node         = var.target_node
      type         = "vm"
      groups       = cfg.ansible_groups
    }
  }

  inventory_hosts = merge(local.lxc_inventory, local.vm_inventory)

  inventory_groups = {
    all = {
      vars = {
        ansible_python_interpreter = "/usr/bin/python3"
      }
      hosts = local.inventory_hosts
    }
  }
}

module "lxc" {
  source   = "./modules/lxc_container"
  for_each = var.lxc_definitions

  target_node  = var.target_node
  default_bridge = var.default_bridge
  default_gateway = var.default_gateway
  default_storage = var.default_storage

  config = each.value
}

module "vm" {
  source   = "./modules/vm_qemu"
  for_each = var.vm_definitions

  target_node  = var.target_node
  default_bridge = var.default_bridge
  default_gateway = var.default_gateway
  default_storage = var.default_storage

  config = each.value
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventories/production/hosts.yml"
  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    inventory_groups = local.inventory_groups
  })
}

output "generated_inventory" {
  value = local_file.ansible_inventory.filename
}
