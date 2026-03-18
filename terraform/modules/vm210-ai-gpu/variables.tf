variable "proxmox_node" { type = string }
variable "clone_vmid" { type = number }
variable "vm_storage" { type = string }
variable "cloudinit_storage" { type = string }
variable "vm_bridge" { type = string }
variable "vm_vlan" {
  type    = number
  default = null
}
variable "ssh_public_key" { type = string }
variable "ansible_user" { type = string }
