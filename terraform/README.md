# Terraform

Shared Terraform stack for Proxmox VMs and LXCs.

## Staged environments

This repo uses two staged Terraform environments that follow the approved 11-step bootstrap flow:

| Environment | Creates | When |
|-------------|---------|------|
| `pfsense` | pfSense VM only (VM 100) | Step 5 |
| `production` | Mint (VM 150) + AI GPU VM + all LXCs | Step 8 |

## Operational entrypoints

```bash
cp terraform.tfvars.example terraform.tfvars

# Step 5: pfSense only
./scripts/terraform-init.sh pfsense
terraform -chdir=terraform/environments/pfsense validate
./scripts/terraform-plan.sh pfsense
./scripts/terraform-apply.sh pfsense

# Step 6: [MANUAL] Install and configure pfSense

# Step 8: Mint + all remaining VMs and LXCs
./scripts/terraform-init.sh production
terraform -chdir=terraform/environments/production validate
./scripts/terraform-plan.sh production
./scripts/terraform-apply.sh production
```

Notes:
- `terraform/` is the shared module source used by the staged environment roots under `terraform/environments/`
- Existing single-state checkouts need a manual state migration before switching to the staged environment roots
- pfSense is created alone in the `pfsense` stage, then installed manually
- Mint is created with the remaining workloads in the `production` stage, not with pfSense
- The site build can be switched between UK and France through `ansible/inventories/production/site_config.yml`
- IPs follow `10.<site_octet>.<vlan>.<host_id>`, for example `10.10.x.x` for UK and `10.20.x.x` for France
- `vm050-mint` is clone-only from a prepared Linux Mint Cinnamon template and adds extra NVMe-style and media-style data disks
- AI VM is clone-only from an Ubuntu Server 24.04 LTS cloud image template and supports repeatable GPU passthrough through Proxmox PCI mappings
- LXCs assume a Debian 12 standard template exists in Proxmox
- LXCs bind-mount host storage into /mnt/appdata and /mnt/media_pool where required
- LXC root password is set via the `lxc_root_password` variable, which should match the Ansible vault password (see README-bootstrap.md step 7.4)
- Only the `production` environment renders the Ansible inventory automatically

## GPU passthrough

GPU PCI passthrough address discovery happens **after** the production Terraform apply has created VM 210, and **before** you expect the AI VM to use the GPU.

Run this on the Proxmox host (not inside a guest):

```bash
lspci -nn | grep -iE 'vga|3d|audio'
```

Use the NVIDIA VGA or 3D controller line, not the GPU audio function. Record
all four values that the passthrough bootstrap prints:

```hcl
vm210_gpu_pci_address = "0000:06:00"
vm210_gpu_device_id = "10de:2504"
vm210_gpu_iommu_group = 29
vm210_gpu_subsystem_id = "1462:397d"
```

Then re-run the production Terraform apply to create the PCI mapping and attach
the GPU.

## SSH public keys

To obtain `ssh_public_key`, run this on the machine where you will run Terraform:

```bash
cat ~/.ssh/id_ed25519.pub
```

Then copy the full line into `terraform.tfvars`:

```hcl
ssh_public_key = "ssh-ed25519 AAAA..."
```

For host-local Ansible from the Proxmox node, the bootstrap helpers can also
generate `terraform/generated/proxmox-host-control.auto.tfvars.json` with
`host_control_ssh_public_key`. The Terraform wrapper scripts automatically load
that generated file when it exists, so fresh guests receive both your operator
key and the Proxmox host control key.

The full walkthrough lives in [README-bootstrap.md](../README-bootstrap.md).
