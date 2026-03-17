# Terraform

Root module for Proxmox VMs and LXCs.

Basic flow:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan
terraform apply
```

Notes:
- pfSense is a starter placeholder VM
- AI VM is a starter VM and should be extended for template clone and GPU passthrough
- LXCs assume a Debian 12 template exists in Proxmox
- LXCs bind-mount host storage into /mnt/appdata and /mnt/media_pool where required
- Terraform renders the Ansible inventory automatically
