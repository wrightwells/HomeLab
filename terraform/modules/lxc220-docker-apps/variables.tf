variable "proxmox_node"        { type = string }
variable "lxc_storage"         { type = string }
variable "vm_bridge"           { type = string }
variable "vm_vlan"             { type = number, default = null }
variable "ssh_public_key"      { type = string }
variable "debian_lxc_template" { type = string }
