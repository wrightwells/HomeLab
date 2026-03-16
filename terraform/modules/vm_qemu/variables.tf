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
  })
}
