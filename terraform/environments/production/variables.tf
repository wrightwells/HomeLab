variable "pm_api_url" {
  type      = string
  sensitive = true
}

variable "build_inventory_file" {
  type    = string
  default = "../../ansible/inventories/production/build_inventory.yml"
}

variable "site_config_file" {
  type    = string
  default = "../../ansible/inventories/production/site_config.yml"
}

variable "pm_api_token_id" {
  type      = string
  sensitive = true
}

variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}

variable "pm_tls_insecure" {
  type    = bool
  default = true
}

variable "proxmox_node" {
  type    = string
  default = "littledown"
}

variable "vm_storage" {
  type    = string
  default = "local-lvm"
}

variable "lxc_storage" {
  type    = string
  default = "local-lvm"
}

variable "cloudinit_storage" {
  type    = string
  default = "local-lvm"
}

variable "pfsense_wan_bridge" {
  type    = string
  default = "vmbr1"
}

variable "pfsense_lan_bridge" {
  type    = string
  default = "vmbr2"
}

variable "pfsense_dmz_bridge" {
  type    = string
  default = "vmbr3"
}

variable "ssh_public_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ansible_user" {
  type    = string
  default = "ansible"
}

variable "ansible_default_user" {
  type    = string
  default = "ansible"
}

variable "ansible_inventory_path" {
  type     = string
  default  = null
  nullable = true
}

variable "resource_profile" {
  type    = string
  default = "balanced_128gb"
}

variable "vm_template_vmid" {
  type = number
}

variable "vm050_mint_template_vmid" {
  type = number
}

variable "vm050_mint_root_disk_size_gb" {
  type    = number
  default = 96
}

variable "vm050_mint_nvme_storage" {
  type    = string
  default = "local-lvm"
}

variable "vm050_mint_nvme_disk_size_gb" {
  type    = number
  default = 128
}

variable "vm050_mint_media_storage" {
  type    = string
  default = "local-lvm"
}

variable "vm050_mint_media_disk_size_gb" {
  type    = number
  default = 512
}

variable "vm210_gpu_pci_address" {
  type    = string
  default = ""
}

variable "debian_lxc_template" {
  type    = string
  default = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}
