module "homelab" {
  source = "../../"

  pm_api_url                    = var.pm_api_url
  pm_api_token_id               = var.pm_api_token_id
  pm_api_token_secret           = var.pm_api_token_secret
  pm_tls_insecure               = var.pm_tls_insecure
  proxmox_node                  = var.proxmox_node
  vm_storage                    = var.vm_storage
  lxc_storage                   = var.lxc_storage
  cloudinit_storage             = var.cloudinit_storage
  pfsense_wan_bridge            = var.pfsense_wan_bridge
  pfsense_lan_bridge            = var.pfsense_lan_bridge
  pfsense_dmz_bridge            = var.pfsense_dmz_bridge
  ssh_public_key                = var.ssh_public_key
  ansible_user                  = var.ansible_user
  ansible_default_user          = var.ansible_default_user
  ansible_inventory_path        = var.ansible_inventory_path
  resource_profile              = var.resource_profile
  vm_template_vmid              = var.vm_template_vmid
  vm050_mint_template_vmid      = var.vm050_mint_template_vmid
  vm050_mint_root_disk_size_gb  = var.vm050_mint_root_disk_size_gb
  vm050_mint_nvme_storage       = var.vm050_mint_nvme_storage
  vm050_mint_nvme_disk_size_gb  = var.vm050_mint_nvme_disk_size_gb
  vm050_mint_media_storage      = var.vm050_mint_media_storage
  vm050_mint_media_disk_size_gb = var.vm050_mint_media_disk_size_gb
  vm210_gpu_pci_address         = var.vm210_gpu_pci_address
  debian_lxc_template           = var.debian_lxc_template
  lxc_root_password             = var.lxc_root_password
  build_inventory_file          = var.build_inventory_file
  site_config_file              = var.site_config_file

  create_pfsense           = false
  create_workloads         = true
  create_mint              = true
  render_ansible_inventory = true
}

output "ansible_inventory_file" {
  value = module.homelab.ansible_inventory_file
}

output "vm100_pfsense_id" {
  value = module.homelab.vm100_pfsense_id
}
