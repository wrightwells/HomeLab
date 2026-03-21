locals {
  ansible_inventory_path_resolved = coalesce(
    var.ansible_inventory_path,
    "${path.module}/../ansible/inventories/production/hosts.ini"
  )

  generated_inventory_groups = {
    for group_name in distinct(flatten([for host in values(local.enabled_inventory_hosts) : host.groups])) :
    group_name => {
      for host_key, host in local.enabled_inventory_hosts :
      host.name => {
        ansible_host = host.ip
        ansible_user = host.user
        extra_vars   = {}
      }
      if contains(host.groups, group_name)
    }
  }
}

resource "local_file" "ansible_inventory" {
  filename = local.ansible_inventory_path_resolved
  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    groups               = local.generated_inventory_groups
    ansible_default_user = var.ansible_default_user
  })
}

output "ansible_inventory_generated_path" {
  value       = local_file.ansible_inventory.filename
  description = "Path to the generated Ansible inventory file"
}
