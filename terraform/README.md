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
- AI VM is clone-only from an Ubuntu Server 24.04 LTS cloud image template and includes a placeholder variable for later GPU passthrough once the real PCI address is known
- LXCs assume a Debian 12 standard template exists in Proxmox
- LXCs bind-mount host storage into /mnt/appdata and /mnt/media_pool where required
- Terraform renders the Ansible inventory automatically
