# Terraform snippet merge notes

## Fast path

Use the inventory files exactly as provided and set:

- `ai_vm_ip = "192.168.1.210"`

in `terraform.tfvars`.

That is enough for `terraform apply` to render the AI VM into `[ai_gpu]`.

## Module-output path

If your AI VM is created by a Terraform module and that module can expose its IP:

1. add an output like the one in `ai_vm_module_output_snippet.tf`
2. expose it at root level
3. replace `var.ai_vm_ip` in `ansible_inventory.tf` with your module output or a local derived from it

## Why this approach is safe

It does not require you to rebuild your existing Proxmox Terraform structure.
It only adds one generated file:

- `ansible/inventories/production/hosts.ini`

and it only depends on Terraform knowing the AI VM IP.
