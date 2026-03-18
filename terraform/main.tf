locals {
  resource_profiles = {
    balanced_32gb = {
      vm100_pfsense          = { cpu = 2, memory = 4096, started = true, on_boot = true }
      vm210_ai_gpu           = { cpu = 4, memory = 12288, started = false, on_boot = false }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc200_docker_services = { cpu = 2, memory = 6144, swap = 512, started = true, start_on_boot = true }
      lxc220_docker_apps     = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc230_docker_media    = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc240_docker_external = { cpu = 2, memory = 3072, swap = 512, started = true, start_on_boot = true }
      lxc250_infra           = { cpu = 1, memory = 2048, swap = 512, started = true, start_on_boot = true }
    }
    ai_focus_32gb = {
      vm100_pfsense          = { cpu = 2, memory = 4096, started = true, on_boot = true }
      vm210_ai_gpu           = { cpu = 8, memory = 24576, started = true, on_boot = true }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc200_docker_services = { cpu = 2, memory = 6144, swap = 512, started = false, start_on_boot = false }
      lxc220_docker_apps     = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc230_docker_media    = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc240_docker_external = { cpu = 2, memory = 3072, swap = 512, started = false, start_on_boot = false }
      lxc250_infra           = { cpu = 1, memory = 2048, swap = 512, started = false, start_on_boot = false }
    }
    balanced_64gb = {
      vm100_pfsense          = { cpu = 2, memory = 4096, started = true, on_boot = true }
      vm210_ai_gpu           = { cpu = 8, memory = 24576, started = true, on_boot = true }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc200_docker_services = { cpu = 4, memory = 8192, swap = 512, started = true, start_on_boot = true }
      lxc220_docker_apps     = { cpu = 3, memory = 6144, swap = 512, started = true, start_on_boot = true }
      lxc230_docker_media    = { cpu = 3, memory = 6144, swap = 512, started = true, start_on_boot = true }
      lxc240_docker_external = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc250_infra           = { cpu = 2, memory = 2048, swap = 512, started = true, start_on_boot = true }
    }
    ai_focus_64gb = {
      vm100_pfsense          = { cpu = 2, memory = 4096, started = true, on_boot = true }
      vm210_ai_gpu           = { cpu = 12, memory = 53248, started = true, on_boot = true }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc200_docker_services = { cpu = 4, memory = 8192, swap = 512, started = false, start_on_boot = false }
      lxc220_docker_apps     = { cpu = 3, memory = 6144, swap = 512, started = false, start_on_boot = false }
      lxc230_docker_media    = { cpu = 3, memory = 6144, swap = 512, started = false, start_on_boot = false }
      lxc240_docker_external = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc250_infra           = { cpu = 2, memory = 2048, swap = 512, started = false, start_on_boot = false }
    }
    balanced_128gb = {
      vm100_pfsense          = { cpu = 2, memory = 4096, started = true, on_boot = true }
      vm210_ai_gpu           = { cpu = 12, memory = 49152, started = true, on_boot = true }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc200_docker_services = { cpu = 4, memory = 10240, swap = 512, started = true, start_on_boot = true }
      lxc220_docker_apps     = { cpu = 4, memory = 8192, swap = 512, started = true, start_on_boot = true }
      lxc230_docker_media    = { cpu = 4, memory = 8192, swap = 512, started = true, start_on_boot = true }
      lxc240_docker_external = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc250_infra           = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
    }
    ai_focus_128gb = {
      vm100_pfsense          = { cpu = 2, memory = 4096, started = true, on_boot = true }
      vm210_ai_gpu           = { cpu = 16, memory = 114688, started = true, on_boot = true }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc200_docker_services = { cpu = 4, memory = 10240, swap = 512, started = false, start_on_boot = false }
      lxc220_docker_apps     = { cpu = 4, memory = 8192, swap = 512, started = false, start_on_boot = false }
      lxc230_docker_media    = { cpu = 4, memory = 8192, swap = 512, started = false, start_on_boot = false }
      lxc240_docker_external = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc250_infra           = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
    }
  }

  profile = local.resource_profiles[var.resource_profile]

  inventory_hosts = {
    vm100_pfsense = {
      name   = "pfsense"
      type   = "vm"
      vmid   = 100
      ip     = "10.10.99.1"
      groups = ["pfsense_firewall"]
      user   = "admin"
    }

    vm210_ai_gpu = {
      name   = "ai-gpu"
      type   = "vm"
      vmid   = 210
      ip     = "10.10.20.210"
      groups = ["ai_gpu", "docker_hosts"]
      user   = var.ansible_user
    }

    lxc066_docker_arr = {
      name   = "docker-arr"
      type   = "lxc"
      vmid   = 166
      ip     = "10.10.66.66"
      groups = ["docker_arr", "docker_hosts"]
      user   = "root"
    }

    lxc200_docker_services = {
      name   = "docker-services"
      type   = "lxc"
      vmid   = 200
      ip     = "10.10.20.200"
      groups = ["docker_services", "docker_hosts"]
      user   = "root"
    }

    lxc220_docker_apps = {
      name   = "docker-apps"
      type   = "lxc"
      vmid   = 220
      ip     = "10.10.20.220"
      groups = ["docker_apps", "docker_hosts"]
      user   = "root"
    }

    lxc230_docker_media = {
      name   = "docker-media"
      type   = "lxc"
      vmid   = 230
      ip     = "10.10.20.230"
      groups = ["docker_media", "docker_hosts"]
      user   = "root"
    }

    lxc240_docker_external = {
      name   = "docker-external"
      type   = "lxc"
      vmid   = 240
      ip     = "10.10.66.240"
      groups = ["docker_external", "docker_hosts"]
      user   = "root"
    }

    lxc250_infra = {
      name   = "infra"
      type   = "lxc"
      vmid   = 250
      ip     = "10.10.20.250"
      groups = ["infra", "docker_hosts"]
      user   = "root"
    }
  }
}

module "vm100_pfsense" {
  source       = "./modules/vm100-pfsense"
  proxmox_node = var.proxmox_node
  vm_storage   = var.vm_storage
  wan_bridge   = var.pfsense_wan_bridge
  lan_bridge   = var.pfsense_lan_bridge
  dmz_bridge   = var.pfsense_dmz_bridge
  cpu_cores    = local.profile.vm100_pfsense.cpu
  memory_mb    = local.profile.vm100_pfsense.memory
  started      = local.profile.vm100_pfsense.started
  on_boot      = local.profile.vm100_pfsense.on_boot
}

module "vm210_ai_gpu" {
  source            = "./modules/vm210-ai-gpu"
  proxmox_node      = var.proxmox_node
  clone_vmid        = var.vm_template_vmid
  vm_storage        = var.vm_storage
  cloudinit_storage = var.cloudinit_storage
  ssh_public_key    = var.ssh_public_key
  ansible_user      = var.ansible_user
  gpu_pci_address   = var.vm210_gpu_pci_address
  cpu_cores         = local.profile.vm210_ai_gpu.cpu
  memory_mb         = local.profile.vm210_ai_gpu.memory
  started           = local.profile.vm210_ai_gpu.started
  on_boot           = local.profile.vm210_ai_gpu.on_boot
}

module "lxc066_docker_arr" {
  source              = "./modules/lxc066-docker-arr"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc066_docker_arr.cpu
  memory_mb           = local.profile.lxc066_docker_arr.memory
  swap_mb             = local.profile.lxc066_docker_arr.swap
  started             = local.profile.lxc066_docker_arr.started
  start_on_boot       = local.profile.lxc066_docker_arr.start_on_boot
}

module "lxc200_docker_services" {
  source              = "./modules/lxc200-docker-services"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc200_docker_services.cpu
  memory_mb           = local.profile.lxc200_docker_services.memory
  swap_mb             = local.profile.lxc200_docker_services.swap
  started             = local.profile.lxc200_docker_services.started
  start_on_boot       = local.profile.lxc200_docker_services.start_on_boot
}

module "lxc220_docker_apps" {
  source              = "./modules/lxc220-docker-apps"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc220_docker_apps.cpu
  memory_mb           = local.profile.lxc220_docker_apps.memory
  swap_mb             = local.profile.lxc220_docker_apps.swap
  started             = local.profile.lxc220_docker_apps.started
  start_on_boot       = local.profile.lxc220_docker_apps.start_on_boot
}

module "lxc230_docker_media" {
  source              = "./modules/lxc230-docker-media"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc230_docker_media.cpu
  memory_mb           = local.profile.lxc230_docker_media.memory
  swap_mb             = local.profile.lxc230_docker_media.swap
  started             = local.profile.lxc230_docker_media.started
  start_on_boot       = local.profile.lxc230_docker_media.start_on_boot
}

module "lxc240_docker_external" {
  source              = "./modules/lxc240-docker-external"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc240_docker_external.cpu
  memory_mb           = local.profile.lxc240_docker_external.memory
  swap_mb             = local.profile.lxc240_docker_external.swap
  started             = local.profile.lxc240_docker_external.started
  start_on_boot       = local.profile.lxc240_docker_external.start_on_boot
}

module "lxc250_infra" {
  source              = "./modules/lxc250-infra"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc250_infra.cpu
  memory_mb           = local.profile.lxc250_infra.memory
  swap_mb             = local.profile.lxc250_infra.swap
  started             = local.profile.lxc250_infra.started
  start_on_boot       = local.profile.lxc250_infra.start_on_boot
}
