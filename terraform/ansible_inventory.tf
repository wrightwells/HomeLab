locals {
  ai_vm_host_entry = (
    var.ai_vm_enabled && trimspace(var.ai_vm_ip) != ""
  ) ? {
    (var.ai_vm_inventory_name) = {
      ansible_host = var.ai_vm_ip
      ansible_user = var.ai_vm_ansible_user
      extra_vars   = {}
    }
  } : {}

  generated_inventory_groups = merge(
    var.existing_inventory_groups,
    {
      for group_name in var.ai_vm_groups :
      group_name => merge(
        lookup(var.existing_inventory_groups, group_name, {}),
        local.ai_vm_host_entry
      )
    }
  )
}

resource "local_file" "ansible_inventory" {
  filename = var.ansible_inventory_path
  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    groups               = local.generated_inventory_groups
    ansible_default_user = var.ansible_default_user
  })
}

output "ansible_inventory_generated_path" {
  value       = local_file.ansible_inventory.filename
  description = "Path to the generated Ansible inventory file"
}
