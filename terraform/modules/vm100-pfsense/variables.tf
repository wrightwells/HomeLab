variable "proxmox_node" { type = string }
variable "vm_storage" { type = string }
variable "vm_bridge" { type = string }
variable "vm_vlan" {
  type    = number
  default = null
}
