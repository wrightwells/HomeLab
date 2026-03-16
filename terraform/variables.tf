variable "pm_api_url" {
  description = "Proxmox API URL, for example https://pve.example.com:8006/api2/json"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID, for example terraform@pve!provider"
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

variable "target_node" {
  description = "Default Proxmox node to place workloads on"
  type        = string
}

variable "default_gateway" {
  description = "Default IPv4 gateway"
  type        = string
}

variable "default_bridge" {
  description = "Default Proxmox bridge"
  type        = string
  default     = "vmbr0"
}

variable "default_storage" {
  description = "Default Proxmox storage target"
  type        = string
  default     = "local-lvm"
}

variable "lxc_definitions" {
  description = "Map of LXC containers to create"
  type = map(object({
    vmid        = number
    hostname    = string
    description = optional(string, "")
    tags        = optional(list(string), [])
    ostemplate  = string
    cores       = number
    memory      = number
    swap        = optional(number, 512)
    rootfs_size = number
    ip_address  = string
    gateway     = optional(string)
    bridge      = optional(string)
    vlan_id     = optional(number)
    onboot      = optional(bool, true)
    unprivileged = optional(bool, true)
    start       = optional(bool, true)
    ansible_groups = optional(list(string), [])
  }))
  default = {}
}

variable "vm_definitions" {
  description = "Map of QEMU VMs to create"
  type = map(object({
    vmid          = number
    name          = string
    description   = optional(string, "")
    tags          = optional(list(string), [])
    clone         = optional(string)
    iso           = optional(string)
    cores         = number
    sockets       = optional(number, 1)
    memory        = number
    disk_size_gb  = number
    ip_address    = string
    gateway       = optional(string)
    bridge        = optional(string)
    vlan_id       = optional(number)
    onboot        = optional(bool, true)
    start_on_boot = optional(bool, true)
    agent         = optional(bool, true)
    ansible_groups = optional(list(string), [])
  }))
  default = {}
}
