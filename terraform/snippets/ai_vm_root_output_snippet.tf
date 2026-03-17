# Example snippet for your root Terraform where the AI VM module is called.
# This lets the generated inventory use the AI VM module output instead of a manually set variable.
# Replace module.ai_vm with your real module name.

# Example module block idea:
# module "ai_vm" {
#   source = "./modules/vm/ubuntu"
#   vm_name = "VM210-AI-GPU"
#   vm_ip   = "192.168.1.210"
# }

# Then either:
# variable "ai_vm_ip" can be removed and replaced with a local
# or you can directly set the variable value from module.ai_vm.vm_ip in your tfvars strategy.

locals {
  ai_vm_ip_from_module = module.ai_vm.vm_ip
}

# In ansible_inventory.tf you could then replace var.ai_vm_ip with local.ai_vm_ip_from_module
# if you prefer a hard-wired module-based design.
