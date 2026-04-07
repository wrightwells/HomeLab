variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^https://", var.pm_api_url))
    error_message = "pm_api_url must be a valid HTTPS URL."
  }
}

variable "build_inventory_file" {
  description = "Path to the shared build inventory YAML file, relative to the terraform root unless absolute"
  type        = string
  default     = "../ansible/inventories/production/build_inventory.yml"
}

variable "site_config_file" {
  description = "Path to the shared site configuration YAML file, relative to the terraform root unless absolute"
  type        = string
  default     = "../ansible/inventories/production/site_config.yml"
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
  description = "Bridge used for the pfSense WAN interface; defaults to the dedicated WAN bridge on nic1"
  type        = string
  default     = "vmbr1"
}

variable "pfsense_lan_bridge" {
  description = "Bridge used for the pfSense LAN/trunk interface for trusted internal VLAN-backed guests; defaults to the nic2 LAN trunk bridge"
  type        = string
  default     = "vmbr2"
}

variable "pfsense_dmz_bridge" {
  description = "Bridge used for the pfSense DMZ interface for isolated or public-facing workloads"
  type        = string
  default     = "vmbr3"
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

variable "resource_profile" {
  description = "Sizing and startup profile for guest CPU, memory, and auto-start behavior"
  type        = string
  default     = "balanced_128gb"
  validation {
    condition = contains([
      "balanced_32gb",
      "ai_focus_32gb",
      "balanced_64gb",
      "ai_focus_64gb",
      "balanced_128gb",
      "ai_focus_128gb",
    ], var.resource_profile)
    error_message = "resource_profile must be one of balanced_32gb, ai_focus_32gb, balanced_64gb, ai_focus_64gb, balanced_128gb, or ai_focus_128gb."
  }
}

variable "vm_template_vmid" {
  description = "Template VMID for the Ubuntu Server 24.04 LTS cloud image used to clone the AI GPU VM"
  type        = number
  validation {
    condition     = var.vm_template_vmid > 0
    error_message = "vm_template_vmid must be a positive VMID."
  }
}

variable "vm050_mint_template_vmid" {
  description = "Template VMID for the Linux Mint Cinnamon desktop VM clone source"
  type        = number
  validation {
    condition     = var.vm050_mint_template_vmid > 0
    error_message = "vm050_mint_template_vmid must be a positive VMID."
  }
}

variable "vm050_mint_root_disk_size_gb" {
  description = "Root disk size for the Linux Mint workstation VM"
  type        = number
  default     = 96
}

variable "vm050_mint_nvme_storage" {
  description = "Storage backing the Linux Mint workstation NVMe-style data disk"
  type        = string
  default     = "local-lvm"
}

variable "vm050_mint_nvme_disk_size_gb" {
  description = "Size of the Linux Mint workstation NVMe-style data disk"
  type        = number
  default     = 128
}

variable "vm050_mint_media_storage" {
  description = "Storage backing the Linux Mint workstation media-style data disk"
  type        = string
  default     = "local-lvm"
}

variable "vm050_mint_media_disk_size_gb" {
  description = "Size of the Linux Mint workstation media-style data disk"
  type        = number
  default     = 512
}

variable "vm210_gpu_pci_address" {
  description = "Optional Proxmox PCI address for later GPU passthrough to vm210, for example 0000:02:00"
  type        = string
  default     = ""
}

variable "debian_lxc_template" {
  description = "Proxmox Debian 12 standard LXC template file id"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}

variable "lxc_root_password" {
  description = "Root password for LXC containers. Uses the same plain-text secret as the Ansible vault password."
  type        = string
  sensitive   = true
}

variable "create_pfsense" {
  description = "Whether this Terraform state should manage the pfSense VM"
  type        = bool
  default     = true
}

variable "create_workloads" {
  description = "Whether this Terraform state should manage the non-pfSense workloads"
  type        = bool
  default     = true
}

variable "create_mint" {
  description = "Whether this Terraform state should manage the Linux Mint desktop VM"
  type        = bool
  default     = true
}

variable "render_ansible_inventory" {
  description = "Whether this Terraform state should render the generated Ansible inventory file"
  type        = bool
  default     = true
}
