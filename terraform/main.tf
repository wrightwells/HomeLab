locals {
  build_inventory_path = abspath(pathexpand(
    startswith(var.build_inventory_file, "/")
    ? var.build_inventory_file
    : "${path.module}/${var.build_inventory_file}"
  ))
  build_inventory = yamldecode(file(local.build_inventory_path)).build_inventory
  site_config_path = abspath(pathexpand(
    startswith(var.site_config_file, "/")
    ? var.site_config_file
    : "${path.module}/${var.site_config_file}"
  ))
  homelab_site = yamldecode(file(local.site_config_path)).homelab_site
  site_networks = {
    bootstrap   = { vlan = local.homelab_site.proxmox.bootstrap_subnet, bridge = local.homelab_site.bridges.bootstrap }
    management  = { vlan = local.homelab_site.addressing.management_vlan, bridge = local.homelab_site.bridges.management }
    workstation = { vlan = local.homelab_site.addressing.workstation_vlan, bridge = local.homelab_site.bridges.trusted }
    servers     = { vlan = local.homelab_site.addressing.server_vlan, bridge = local.homelab_site.bridges.trusted }
    dmz         = { vlan = local.homelab_site.addressing.dmz_vlan, bridge = local.homelab_site.bridges.dmz }
  }

  resource_profiles = {
    balanced_32gb = {
      vm100_pfsense          = { cpu = 2, memory = 8192, started = true, on_boot = true }
      vm050_mint             = { cpu = 2, memory = 4096, started = false, on_boot = false }
      vm210_ai_gpu           = { cpu = 4, memory = 12288, started = false, on_boot = false }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc200_docker_services = { cpu = 2, memory = 6144, swap = 512, started = true, start_on_boot = true }
      lxc220_docker_apps     = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc230_docker_media    = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc240_docker_external = { cpu = 2, memory = 3072, swap = 512, started = true, start_on_boot = true }
      lxc250_infra           = { cpu = 1, memory = 2048, swap = 512, started = true, start_on_boot = true }
    }
    ai_focus_32gb = {
      vm100_pfsense          = { cpu = 2, memory = 8192, started = true, on_boot = true }
      vm050_mint             = { cpu = 2, memory = 4096, started = false, on_boot = false }
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
      vm050_mint             = { cpu = 4, memory = 8192, started = true, on_boot = true }
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
      vm050_mint             = { cpu = 2, memory = 4096, started = false, on_boot = false }
      vm210_ai_gpu           = { cpu = 12, memory = 53248, started = true, on_boot = true }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc200_docker_services = { cpu = 4, memory = 8192, swap = 512, started = false, start_on_boot = false }
      lxc220_docker_apps     = { cpu = 3, memory = 6144, swap = 512, started = false, start_on_boot = false }
      lxc230_docker_media    = { cpu = 3, memory = 6144, swap = 512, started = false, start_on_boot = false }
      lxc240_docker_external = { cpu = 2, memory = 4096, swap = 512, started = false, start_on_boot = false }
      lxc250_infra           = { cpu = 2, memory = 2048, swap = 512, started = false, start_on_boot = false }
    }
    balanced_128gb = {
      vm100_pfsense          = { cpu = 2, memory = 8192, started = true, on_boot = true }
      vm050_mint             = { cpu = 4, memory = 8192, started = true, on_boot = true }
      vm210_ai_gpu           = { cpu = 12, memory = 49152, started = true, on_boot = true }
      lxc066_docker_arr      = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc200_docker_services = { cpu = 4, memory = 10240, swap = 512, started = true, start_on_boot = true }
      lxc220_docker_apps     = { cpu = 4, memory = 8192, swap = 512, started = true, start_on_boot = true }
      lxc230_docker_media    = { cpu = 4, memory = 8192, swap = 512, started = true, start_on_boot = true }
      lxc240_docker_external = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
      lxc250_infra           = { cpu = 2, memory = 4096, swap = 512, started = true, start_on_boot = true }
    }
    ai_focus_128gb = {
      vm100_pfsense          = { cpu = 2, memory = 8192, started = true, on_boot = true }
      vm050_mint             = { cpu = 2, memory = 4096, started = false, on_boot = false }
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
  guest_enabled = merge(
    { vm100_pfsense = true },
    {
      for guest_name, guest in local.build_inventory.guests :
      guest_name => try(guest.enabled, false)
    }
  )

  inventory_hosts = {
    proxmox_host = {
      name    = "proxmox-host"
      type    = "host"
      network = "bootstrap"
      vmid    = null
      host_id = local.homelab_site.proxmox.management_host_id
      groups  = ["proxmox"]
      user    = "root"
    }

    vm100_pfsense = {
      name    = local.homelab_site.guests.vm100_pfsense.hostname
      type    = "vm"
      network = local.homelab_site.guests.vm100_pfsense.network
      vmid    = 100
      host_id = local.homelab_site.guests.vm100_pfsense.host_id
      groups  = ["pfsense_firewall"]
      user    = "admin"
    }

    vm050_mint = {
      name    = local.homelab_site.guests.vm050_mint.hostname
      type    = "vm"
      network = local.homelab_site.guests.vm050_mint.network
      vmid    = 150
      host_id = local.homelab_site.guests.vm050_mint.host_id
      groups  = ["mint_desktop"]
      user    = var.ansible_user
    }

    vm210_ai_gpu = {
      name    = local.homelab_site.guests.vm210_ai_gpu.hostname
      type    = "vm"
      network = local.homelab_site.guests.vm210_ai_gpu.network
      vmid    = 210
      host_id = local.homelab_site.guests.vm210_ai_gpu.host_id
      groups  = ["ai_gpu", "docker_hosts"]
      user    = var.ansible_user
    }

    lxc066_docker_arr = {
      name    = local.homelab_site.guests.lxc066_docker_arr.hostname
      type    = "lxc"
      network = local.homelab_site.guests.lxc066_docker_arr.network
      vmid    = 166
      host_id = local.homelab_site.guests.lxc066_docker_arr.host_id
      groups  = ["docker_arr", "docker_hosts"]
      user    = "root"
    }

    lxc200_docker_services = {
      name    = local.homelab_site.guests.lxc200_docker_services.hostname
      type    = "lxc"
      network = local.homelab_site.guests.lxc200_docker_services.network
      vmid    = 200
      host_id = local.homelab_site.guests.lxc200_docker_services.host_id
      groups  = ["docker_services", "docker_hosts"]
      user    = "root"
    }

    lxc220_docker_apps = {
      name    = local.homelab_site.guests.lxc220_docker_apps.hostname
      type    = "lxc"
      network = local.homelab_site.guests.lxc220_docker_apps.network
      vmid    = 220
      host_id = local.homelab_site.guests.lxc220_docker_apps.host_id
      groups  = ["docker_apps", "docker_hosts"]
      user    = "root"
    }

    lxc230_docker_media = {
      name    = local.homelab_site.guests.lxc230_docker_media.hostname
      type    = "lxc"
      network = local.homelab_site.guests.lxc230_docker_media.network
      vmid    = 230
      host_id = local.homelab_site.guests.lxc230_docker_media.host_id
      groups  = ["docker_media", "docker_hosts"]
      user    = "root"
    }

    lxc240_docker_external = {
      name    = local.homelab_site.guests.lxc240_docker_external.hostname
      type    = "lxc"
      network = local.homelab_site.guests.lxc240_docker_external.network
      vmid    = 240
      host_id = local.homelab_site.guests.lxc240_docker_external.host_id
      groups  = ["docker_external", "docker_hosts"]
      user    = "root"
    }

    lxc250_infra = {
      name    = local.homelab_site.guests.lxc250_infra.hostname
      type    = "lxc"
      network = local.homelab_site.guests.lxc250_infra.network
      vmid    = 250
      host_id = local.homelab_site.guests.lxc250_infra.host_id
      groups  = ["infra", "docker_hosts"]
      user    = "root"
    }
  }

  all_inventory_hosts = {
    for host_key, host in local.inventory_hosts :
    host_key => merge(host, {
      ip      = format("%d.%d.%d.%d", local.homelab_site.addressing.first_octet, local.homelab_site.addressing.second_octet, local.site_networks[host.network].vlan, host.host_id)
      gateway = format("%d.%d.%d.%d", local.homelab_site.addressing.first_octet, local.homelab_site.addressing.second_octet, local.site_networks[host.network].vlan, local.homelab_site.addressing.gateway_host)
    })
  }

  enabled_inventory_hosts = {
    for host_key, host in local.all_inventory_hosts :
    host_key => host
    if host_key == "proxmox_host" || host_key == "vm100_pfsense" || try(local.guest_enabled[host_key], false)
  }
}

module "vm100_pfsense" {
  count            = var.create_pfsense ? 1 : 0
  source           = "./modules/vm100-pfsense"
  proxmox_node     = var.proxmox_node
  vm_storage       = var.vm_storage
  bootstrap_bridge = local.homelab_site.bridges.bootstrap
  wan_bridge       = var.pfsense_wan_bridge
  lan_bridge       = var.pfsense_lan_bridge
  dmz_bridge       = var.pfsense_dmz_bridge
  cpu_cores        = local.profile.vm100_pfsense.cpu
  memory_mb        = local.profile.vm100_pfsense.memory
  started          = local.profile.vm100_pfsense.started
  on_boot          = local.profile.vm100_pfsense.on_boot
}

module "vm050_mint" {
  count              = var.create_mint && local.guest_enabled.vm050_mint ? 1 : 0
  source             = "./modules/vm050-mint"
  name               = local.inventory_hosts.vm050_mint.name
  vm_id              = 150
  proxmox_node       = var.proxmox_node
  clone_vmid         = var.vm050_mint_template_vmid
  vm_storage         = var.vm_storage
  nvme_storage       = var.vm050_mint_nvme_storage
  media_storage      = var.vm050_mint_media_storage
  cloudinit_storage  = var.cloudinit_storage
  ssh_public_key     = var.ssh_public_key
  ansible_user       = var.ansible_user
  cpu_cores          = local.profile.vm050_mint.cpu
  memory_mb          = local.profile.vm050_mint.memory
  started            = local.profile.vm050_mint.started
  on_boot            = local.profile.vm050_mint.on_boot
  root_disk_size_gb  = var.vm050_mint_root_disk_size_gb
  nvme_disk_size_gb  = var.vm050_mint_nvme_disk_size_gb
  media_disk_size_gb = var.vm050_mint_media_disk_size_gb
  ipv4_address       = "${local.all_inventory_hosts.vm050_mint.ip}/24"
  ipv4_gateway       = local.all_inventory_hosts.vm050_mint.gateway
  bridge             = local.site_networks[local.inventory_hosts.vm050_mint.network].bridge
  vlan_id            = local.site_networks[local.inventory_hosts.vm050_mint.network].vlan
}

module "vm210_ai_gpu" {
  count             = var.create_workloads && local.guest_enabled.vm210_ai_gpu ? 1 : 0
  source            = "./modules/vm210-ai-gpu"
  name              = local.inventory_hosts.vm210_ai_gpu.name
  vm_id             = 210
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
  ipv4_address      = "${local.all_inventory_hosts.vm210_ai_gpu.ip}/24"
  ipv4_gateway      = local.all_inventory_hosts.vm210_ai_gpu.gateway
  bridge            = local.site_networks[local.inventory_hosts.vm210_ai_gpu.network].bridge
  vlan_id           = local.site_networks[local.inventory_hosts.vm210_ai_gpu.network].vlan
}

module "lxc066_docker_arr" {
  count               = var.create_workloads && local.guest_enabled.lxc066_docker_arr ? 1 : 0
  source              = "./modules/lxc066-docker-arr"
  proxmox_node        = var.proxmox_node
  vm_id               = 166
  hostname            = local.inventory_hosts.lxc066_docker_arr.name
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc066_docker_arr.cpu
  memory_mb           = local.profile.lxc066_docker_arr.memory
  swap_mb             = local.profile.lxc066_docker_arr.swap
  started             = local.profile.lxc066_docker_arr.started
  start_on_boot       = local.profile.lxc066_docker_arr.start_on_boot
  ipv4_address        = "${local.all_inventory_hosts.lxc066_docker_arr.ip}/24"
  ipv4_gateway        = local.all_inventory_hosts.lxc066_docker_arr.gateway
  bridge              = local.site_networks[local.inventory_hosts.lxc066_docker_arr.network].bridge
  vlan_id             = local.inventory_hosts.lxc066_docker_arr.network == "dmz" ? null : local.site_networks[local.inventory_hosts.lxc066_docker_arr.network].vlan
  lxc_root_password   = var.lxc_root_password
}

module "lxc200_docker_services" {
  count               = var.create_workloads && local.guest_enabled.lxc200_docker_services ? 1 : 0
  source              = "./modules/lxc200-docker-services"
  proxmox_node        = var.proxmox_node
  vm_id               = 200
  hostname            = local.inventory_hosts.lxc200_docker_services.name
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc200_docker_services.cpu
  memory_mb           = local.profile.lxc200_docker_services.memory
  swap_mb             = local.profile.lxc200_docker_services.swap
  started             = local.profile.lxc200_docker_services.started
  start_on_boot       = local.profile.lxc200_docker_services.start_on_boot
  ipv4_address        = "${local.all_inventory_hosts.lxc200_docker_services.ip}/24"
  ipv4_gateway        = local.all_inventory_hosts.lxc200_docker_services.gateway
  bridge              = local.site_networks[local.inventory_hosts.lxc200_docker_services.network].bridge
  vlan_id             = local.site_networks[local.inventory_hosts.lxc200_docker_services.network].vlan
  lxc_root_password   = var.lxc_root_password
}

module "lxc220_docker_apps" {
  count               = var.create_workloads && local.guest_enabled.lxc220_docker_apps ? 1 : 0
  source              = "./modules/lxc220-docker-apps"
  proxmox_node        = var.proxmox_node
  vm_id               = 220
  hostname            = local.inventory_hosts.lxc220_docker_apps.name
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc220_docker_apps.cpu
  memory_mb           = local.profile.lxc220_docker_apps.memory
  swap_mb             = local.profile.lxc220_docker_apps.swap
  started             = local.profile.lxc220_docker_apps.started
  start_on_boot       = local.profile.lxc220_docker_apps.start_on_boot
  ipv4_address        = "${local.all_inventory_hosts.lxc220_docker_apps.ip}/24"
  ipv4_gateway        = local.all_inventory_hosts.lxc220_docker_apps.gateway
  bridge              = local.site_networks[local.inventory_hosts.lxc220_docker_apps.network].bridge
  vlan_id             = local.site_networks[local.inventory_hosts.lxc220_docker_apps.network].vlan
  lxc_root_password   = var.lxc_root_password
}

module "lxc230_docker_media" {
  count               = var.create_workloads && local.guest_enabled.lxc230_docker_media ? 1 : 0
  source              = "./modules/lxc230-docker-media"
  proxmox_node        = var.proxmox_node
  vm_id               = 230
  hostname            = local.inventory_hosts.lxc230_docker_media.name
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc230_docker_media.cpu
  memory_mb           = local.profile.lxc230_docker_media.memory
  swap_mb             = local.profile.lxc230_docker_media.swap
  started             = local.profile.lxc230_docker_media.started
  start_on_boot       = local.profile.lxc230_docker_media.start_on_boot
  ipv4_address        = "${local.all_inventory_hosts.lxc230_docker_media.ip}/24"
  ipv4_gateway        = local.all_inventory_hosts.lxc230_docker_media.gateway
  bridge              = local.site_networks[local.inventory_hosts.lxc230_docker_media.network].bridge
  vlan_id             = local.site_networks[local.inventory_hosts.lxc230_docker_media.network].vlan
  lxc_root_password   = var.lxc_root_password
}

module "lxc240_docker_external" {
  count               = var.create_workloads && local.guest_enabled.lxc240_docker_external ? 1 : 0
  source              = "./modules/lxc240-docker-external"
  proxmox_node        = var.proxmox_node
  vm_id               = 240
  hostname            = local.inventory_hosts.lxc240_docker_external.name
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc240_docker_external.cpu
  memory_mb           = local.profile.lxc240_docker_external.memory
  swap_mb             = local.profile.lxc240_docker_external.swap
  started             = local.profile.lxc240_docker_external.started
  start_on_boot       = local.profile.lxc240_docker_external.start_on_boot
  ipv4_address        = "${local.all_inventory_hosts.lxc240_docker_external.ip}/24"
  ipv4_gateway        = local.all_inventory_hosts.lxc240_docker_external.gateway
  bridge              = local.site_networks[local.inventory_hosts.lxc240_docker_external.network].bridge
  vlan_id             = local.inventory_hosts.lxc240_docker_external.network == "dmz" ? null : local.site_networks[local.inventory_hosts.lxc240_docker_external.network].vlan
  lxc_root_password   = var.lxc_root_password
}

module "lxc250_infra" {
  count               = var.create_workloads && local.guest_enabled.lxc250_infra ? 1 : 0
  source              = "./modules/lxc250-infra"
  proxmox_node        = var.proxmox_node
  vm_id               = 250
  hostname            = local.inventory_hosts.lxc250_infra.name
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
  cpu_cores           = local.profile.lxc250_infra.cpu
  memory_mb           = local.profile.lxc250_infra.memory
  swap_mb             = local.profile.lxc250_infra.swap
  started             = local.profile.lxc250_infra.started
  start_on_boot       = local.profile.lxc250_infra.start_on_boot
  ipv4_address        = "${local.all_inventory_hosts.lxc250_infra.ip}/24"
  ipv4_gateway        = local.all_inventory_hosts.lxc250_infra.gateway
  bridge              = local.site_networks[local.inventory_hosts.lxc250_infra.network].bridge
  vlan_id             = local.site_networks[local.inventory_hosts.lxc250_infra.network].vlan
  lxc_root_password   = var.lxc_root_password
}

moved {
  from = module.vm100_pfsense
  to   = module.vm100_pfsense[0]
}
