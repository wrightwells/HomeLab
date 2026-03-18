variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^https://", var.pm_api_url))
    error_message = "pm_api_url must be a valid HTTPS URL."
  }
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

variable "pm_tls_insecure" {
  description = "Set true when using self-signed Proxmox TLS certificates"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "littledown"
  validation {
    condition     = length(trimspace(var.proxmox_node)) > 0
    error_message = "proxmox_node cannot be empty."
  }
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

variable "pfsense_wan_bridge" {
  description = "Bridge used for the pfSense WAN interface"
  type        = string
  default     = "vmbr0"
}

variable "pfsense_lan_bridge" {
  description = "Bridge used for the pfSense LAN/trunk interface"
  type        = string
  default     = "vmbr1"
}

variable "pfsense_dmz_bridge" {
  description = "Bridge used for the pfSense DMZ interface"
  type        = string
  default     = "vmbr2"
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

variable "vm210_clone_vmid" {
  description = "Template VMID used to clone the AI GPU VM"
  type        = number
  validation {
    condition     = var.vm210_clone_vmid > 0
    error_message = "vm210_clone_vmid must be a positive VMID."
  }
}

variable "vm210_gpu_pci_address" {
  description = "Optional Proxmox PCI address for later GPU passthrough to vm210, for example 0000:02:00"
  type        = string
  default     = ""
}

variable "debian_lxc_template" {
  description = "Proxmox LXC template file id"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}
