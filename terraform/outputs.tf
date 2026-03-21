output "ansible_inventory_file" {
  value = local_file.ansible_inventory.filename
}

output "vm100_pfsense_id" {
  value = module.vm100_pfsense.vm_id
}

output "vm050_mint_id" {
  value = try(module.vm050_mint[0].vm_id, null)
}

output "vm210_ai_gpu_id" {
  value = try(module.vm210_ai_gpu[0].vm_id, null)
}

output "lxc066_docker_arr_id" {
  value = try(module.lxc066_docker_arr[0].vm_id, null)
}

output "lxc200_docker_services_id" {
  value = try(module.lxc200_docker_services[0].vm_id, null)
}

output "lxc220_docker_apps_id" {
  value = try(module.lxc220_docker_apps[0].vm_id, null)
}

output "lxc230_docker_media_id" {
  value = try(module.lxc230_docker_media[0].vm_id, null)
}

output "lxc240_docker_external_id" {
  value = try(module.lxc240_docker_external[0].vm_id, null)
}

output "lxc250_infra_id" {
  value = try(module.lxc250_infra[0].vm_id, null)
}
