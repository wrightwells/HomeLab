variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "littledown"
}

variable "vm_storage" {
  description = "Storage for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "lxc_storage" {
  description = "Storage for LXC rootfs"
  type        = string
  default     = "local-lvm"
}

variable "cloudinit_storage" {
  description = "Storage for cloud-init"
  type        = string
  default     = "local-lvm"
}

variable "vm_bridge" {
  description = "Bridge name"
  type        = string
  default     = "vmbr0"
}

variable "vm_vlan" {
  description = "Optional VLAN tag"
  type        = number
  default     = null
}

variable "ssh_public_key" {
  description = "SSH public key for guests"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ansible_user" {
  description = "Ansible SSH username"
  type        = string
  default     = "ansible"
}

variable "debian_lxc_template" {
  description = "Proxmox LXC template file id"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}
