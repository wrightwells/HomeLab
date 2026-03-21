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
- The site build can be switched between UK and France through `ansible/inventories/production/site_config.yml`
- IPs follow `10.<site_octet>.<vlan>.<host_id>`, for example `10.10.x.x` for UK and `10.20.x.x` for France
- `vm050-mint` is clone-only from a prepared Linux Mint Cinnamon template and adds extra NVMe-style and media-style data disks
- AI VM is clone-only from an Ubuntu Server 24.04 LTS cloud image template and includes a placeholder variable for later GPU passthrough once the real PCI address is known
- LXCs assume a Debian 12 standard template exists in Proxmox
- LXCs bind-mount host storage into /mnt/appdata and /mnt/media_pool where required
- Terraform renders the Ansible inventory automatically
