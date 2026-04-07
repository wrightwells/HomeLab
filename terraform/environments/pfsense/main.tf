module "homelab" {
  source = "../../"

  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
  proxmox_node        = var.proxmox_node
  vm_storage          = var.vm_storage
  lxc_storage         = var.lxc_storage
  cloudinit_storage   = var.cloudinit_storage
  pfsense_wan_bridge  = var.pfsense_wan_bridge
  pfsense_lan_bridge  = var.pfsense_lan_bridge
  pfsense_dmz_bridge  = var.pfsense_dmz_bridge
  ssh_public_key      = var.ssh_public_key
  ansible_user        = var.ansible_user
  resource_profile    = var.resource_profile
  vm_template_vmid    = var.vm_template_vmid
  vm210_gpu_pci_address = var.vm210_gpu_pci_address
  debian_lxc_template    = var.debian_lxc_template
  lxc_root_password      = var.lxc_root_password
  build_inventory_file  = "environments/pfsense/build_inventory.yml"
  site_config_file    = var.site_config_file

  create_pfsense           = true
  create_workloads         = false
  create_mint              = false
  render_ansible_inventory = false
}

output "vm100_pfsense_id" {
  value = module.homelab.vm100_pfsense_id
}
