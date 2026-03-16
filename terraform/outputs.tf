output "ansible_inventory_file" {
  value = local_file.ansible_inventory.filename
}

output "vm100_pfsense_id" {
  value = module.vm100_pfsense.vm_id
}

output "vm210_ai_gpu_id" {
  value = module.vm210_ai_gpu.vm_id
}

output "lxc066_docker_arr_id" {
  value = module.lxc066_docker_arr.vm_id
}

output "lxc200_docker_services_id" {
  value = module.lxc200_docker_services.vm_id
}

output "lxc220_docker_apps_id" {
  value = module.lxc220_docker_apps.vm_id
}

output "lxc230_docker_media_id" {
  value = module.lxc230_docker_media.vm_id
}

output "lxc240_docker_external_id" {
  value = module.lxc240_docker_external.vm_id
}

output "lxc250_infra_id" {
  value = module.lxc250_infra.vm_id
}
