locals {
  inventory_hosts = {
    vm100_pfsense = {
      name   = "pfsense"
      type   = "vm"
      vmid   = 100
      ip     = "dhcp"
      groups = ["firewall"]
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
}

module "lxc066_docker_arr" {
  source              = "./modules/lxc066-docker-arr"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc200_docker_services" {
  source              = "./modules/lxc200-docker-services"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc220_docker_apps" {
  source              = "./modules/lxc220-docker-apps"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc230_docker_media" {
  source              = "./modules/lxc230-docker-media"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc240_docker_external" {
  source              = "./modules/lxc240-docker-external"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc250_infra" {
  source              = "./modules/lxc250-infra"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}
