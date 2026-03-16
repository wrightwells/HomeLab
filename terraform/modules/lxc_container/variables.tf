variable "target_node" {
  type = string
}

variable "default_bridge" {
  type = string
}

variable "default_gateway" {
  type = string
}

variable "default_storage" {
  type = string
}

variable "config" {
  type = object({
    vmid         = number
    hostname     = string
    description  = optional(string, "")
    tags         = optional(list(string), [])
    ostemplate   = string
    cores        = number
    memory       = number
    swap         = optional(number, 512)
    rootfs_size  = number
    ip_address   = string
    gateway      = optional(string)
    bridge       = optional(string)
    vlan_id      = optional(number)
    onboot       = optional(bool, true)
    unprivileged = optional(bool, true)
    start        = optional(bool, true)
    ansible_groups = optional(list(string), [])
  })
}
