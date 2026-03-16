# HomeLab

Infrastructure-as-code starter repository for a Proxmox-based homelab.

## Repository layout

- `terraform/` - Proxmox VM/LXC definitions and generated Ansible inventory
- `ansible/` - host configuration, Docker host setup, common roles
- `docker/compose/` - application stacks deployed onto selected hosts
- `scripts/` - helper scripts for validation and local workflows
- `layout/` - notes, diagrams, and planning documentation

## Typical workflow

1. Edit `terraform/terraform.tfvars` with your Proxmox details and desired VM/LXC definitions.
2. Run Terraform to create or update infrastructure.
3. Terraform writes a generated inventory file to `ansible/inventories/production/hosts.yml`.
4. Run Ansible against that inventory.
5. Deploy application stacks on the Docker hosts.

## First run

```bash
cd /opt/HomeLab/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply

cd /opt/HomeLab
ansible-inventory -i ansible/inventories/production/hosts.yml --graph
ansible-playbook -i ansible/inventories/production/hosts.yml ansible/playbooks/site.yml
```

## Notes

- The generated inventory file is managed by Terraform.
- Keep secrets out of Git. Use environment variables, Ansible Vault, or a secret manager.
- This is a starter scaffold and should be adapted to your exact storage, network, and VM/LXC templates.
