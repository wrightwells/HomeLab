# Bootstrap Guide

This guide walks through the initial setup of this repo on a host that already
has:

- Proxmox VE installed
- Terraform installed
- Ansible installed

It assumes:

- the onboard NIC is your Proxmox management connection
- that management network is connected to a router at `10.10.99.1`
- Proxmox itself should use a fixed management IP on that network
- a separate NIC will later be used by pfSense for WAN/LAN duties

## 1. Gather the required information

Before you run anything, collect the following:

- Proxmox node name
- Proxmox API endpoint
- Proxmox API token ID
- Proxmox API token secret
- desired fixed management IP for the Proxmox host
- storage names for:
  - VM disks
  - LXC root filesystems
  - cloud-init disks
- the VMID of the prepared Ubuntu Server 24.04 LTS VM template clone source
- the RTX 3060 PCI address later, after the host is built, for example `0000:02:00`
- the Debian LXC template path already present in Proxmox
- your Ansible SSH public key
- your Ansible vault password

## 2. Configure the Proxmox host network manually

Terraform in this repo does not configure the Proxmox host networking or write
`/etc/network/interfaces`. You must create the host NIC and bridge layout
manually first. Terraform only attaches VMs and LXCs to bridges that already
exist in Proxmox.

Use the onboard NIC as the fixed management interface.

Example `/etc/network/interfaces` layout:

```text
# Loopback
auto lo
iface lo inet loopback

# Onboard NIC for Proxmox management
auto eno1
iface eno1 inet static
    address 10.10.99.10/24
    gateway 10.10.99.1
# Only for Proxmox host access, no VLANs, isolated from data traffic

# X520 Port 1 - WAN
auto enp2s0
iface enp2s0 inet manual
# Directly connected to ISP, used by pfSense VM

# X520 Port 2 - LAN trunk to managed switch
auto enp2s1
iface enp2s1 inet manual
# Carries all internal VLANs to switch, pfSense handles tagging/routing

# WAN bridge for pfSense VM
auto vmbr0
iface vmbr0 inet manual
    bridge-ports enp2s0
    bridge-stp off
    bridge-fd 0

# VLAN-aware LAN bridge (trunk for pfSense to handle VLANs 10-60)
auto vmbr1
iface vmbr1 inet manual
    bridge-ports enp2s1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# Optional untrusted bridge for AI VM / experimental LXCs
auto vmbr2
iface vmbr2 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

Notes:

- Replace `eno1`, `enp2s0`, and `enp2s1` with the real NIC names on your host.
- Replace `10.10.99.10/24` with the fixed Proxmox management IP you want.
- `vmbr0` is intended for pfSense WAN.
- `vmbr1` is intended for pfSense LAN/trunk and internal VM/LXC networking.
- `vmbr2` is optional and can be used for isolated or experimental workloads.
- Guests on the internal network should use `bridge = "vmbr1"` with `vlan_id = 20`.
- You do not need host-side bridge names like `vmbr1.20` for guest attachment in this repo.
- `vmbr2` is treated as a separate DMZ-style segment, so guests there do not use `vlan_id = 66`.
- Apply network changes carefully, especially on a remote host.

## 3. Create the Proxmox API token

Create an API token in Proxmox for Terraform.

You will need:

- token ID, for example `terraform@pve!provider`
- token secret

Then update:

- [terraform.tfvars.example](/home/ww/HomeLab/HomeLab/terraform/terraform.tfvars.example)
- your local `terraform/terraform.tfvars`

The key values are:

```hcl
pm_api_url          = "https://YOUR-PROXMOX-IP:8006/api2/json"
pm_api_token_id     = "terraform@pve!provider"
pm_api_token_secret = "REPLACE_ME"
pm_tls_insecure     = true
```

## 4. Prepare Proxmox templates and storage

Before applying Terraform, make sure Proxmox already has:

- the Debian LXC template referenced by `debian_lxc_template`
- a prepared VM template for the AI VM clone source
- the required storage targets such as `local-lvm`

### LXC template

Debian LXC templates can be downloaded from Proxmox's template repository via
`pveam`. Proxmox documents that templates are available through both the GUI
and `pveam`.

Example on the Proxmox host:

```bash
pveam update
pveam available | grep debian-12
pveam download local debian-12-standard_12.*_amd64.tar.zst
```

In the Proxmox GUI:

```text
Node -> local -> CT Templates -> Templates
```

### VM template

For the AI VM clone source, download an Ubuntu cloud image onto the Proxmox
host and convert it into a Proxmox template.

Example download on the Proxmox host:

```bash
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

Then turn it into a Proxmox template:

```bash
qm create 9000 --name ubuntu-2404-ai-template --memory 4096 --cores 4 --net0 virtio,bridge=vmbr0
qm importdisk 9000 /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

The AI VM in this repo is clone-only, so you must provide a valid Ubuntu Server
24.04 LTS template VMID.

Example:

```hcl
vm_template_vmid = 9000
```

If you want the host storage prepared by Ansible, run the dedicated Proxmox host
storage playbook before Terraform:

- [README-storage.md](/home/ww/HomeLab/HomeLab/README-storage.md)
- [proxmox-storage.yml](/home/ww/HomeLab/HomeLab/ansible/playbooks/proxmox-storage.yml)

Treat [README-storage.md](/home/ww/HomeLab/HomeLab/README-storage.md) as the
detailed sub-guide for this one first-install step, then return here and
continue the main bootstrap checklist.

## 5. Create the Ansible vault password file

Create a local vault password file on the machine where you will run Ansible:

```bash
mkdir -p ~/.config/ansible
printf '%s\n' 'REPLACE_WITH_YOUR_VAULT_PASSWORD' > ~/.config/ansible/homelab-vault-pass.txt
chmod 600 ~/.config/ansible/homelab-vault-pass.txt
```

This file is not committed to git.

The helper scripts in [`scripts/`](/home/ww/HomeLab/HomeLab/scripts) will use:

```text
~/.config/ansible/homelab-vault-pass.txt
```

by default, or you can override it with:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=/path/to/your/vault-password-file
```

## 6. Install required Ansible collections

From the repo root:

```bash
./scripts/ansible-install.sh
```

This installs the collections declared in:

- [requirements.yml](/home/ww/HomeLab/HomeLab/ansible/requirements.yml)

## 7. Bootstrap Proxmox host storage if required

If this is the first build and you want Ansible to prepare the host NVMe,
appdata ZFS mirror, and initial MergerFS media disk, update:

- [proxmox.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/group_vars/proxmox.yml)

Then run:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-storage.yml
```

Before you run that playbook, replace the placeholder `/dev/disk/by-id/...`
values in:

- [proxmox.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/group_vars/proxmox.yml)

After the initial format-and-create run, set:

```yaml
proxmox_storage_allow_destructive_create: false
```

## 8. Configure Terraform variables

Copy the example file and update it:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Set at least:

- `pm_api_url`
- `pm_api_token_id`
- `pm_api_token_secret`
- `pm_tls_insecure`
- `proxmox_node`
- `vm_template_vmid`
- `vm210_gpu_pci_address`
- `vm_storage`
- `lxc_storage`
- `cloudinit_storage`
- `pfsense_wan_bridge`
- `pfsense_lan_bridge`
- `pfsense_dmz_bridge`
- `debian_lxc_template`
- `ansible_user`
- `ssh_public_key`

## Current guest IP layout

- Proxmox host management IP: `10.10.99.10/24` on `eno1`
- `vm100_pfsense`: `10.10.99.1` on `vmbr0`
- `vm210_ai_gpu`: `10.10.20.210` on `vmbr1` with VLAN tag `20`
- `lxc066_docker_arr`: `10.10.66.66` on `vmbr2`
- `lxc200_docker_services`: `10.10.20.200` on `vmbr1` with VLAN tag `20`
- `lxc220_docker_apps`: `10.10.20.220` on `vmbr1` with VLAN tag `20`
- `lxc230_docker_media`: `10.10.20.230` on `vmbr1` with VLAN tag `20`
- `lxc240_docker_external`: `10.10.66.240` on `vmbr2`
- `lxc250_infra`: `10.10.20.250` on `vmbr1` with VLAN tag `20`

## Network intent

- `vmbr1` is the trusted internal trunk, and the current workloads use VLAN `20` on the `10.10.20.0/24` segment.
- `vmbr2` is the DMZ-style network for isolated or public-facing workloads on the `10.10.66.0/24` segment.
- `lxc066_docker_arr` stays on `vmbr2` and should not have broad access back into the trusted internal network.
- `lxc240_docker_external` stays on `vmbr2` because it serves public-facing workloads.
- `lxc250_infra` stays on `vmbr1` so the reverse proxy can reach trusted internal services directly.
- pfSense needs separate WAN, LAN/trunk, and DMZ interfaces for this design.
- External exposure and NAT are expected to be handled in pfSense, not Terraform.

## 9. Initialize and validate Terraform

Run:

```bash
./scripts/terraform-init.sh
terraform -chdir=terraform validate
./scripts/terraform-plan.sh
```

Review the plan before applying.

## 10. Apply Terraform

Run:

```bash
./scripts/terraform-apply.sh
```

Terraform will:

- create the declared Proxmox VMs and LXCs
- render the Ansible inventory file used by the playbooks

## 11. Add GPU passthrough later, after the Proxmox host exists

The AI VM can be created now without the RTX 3060 attached. Once the host is
built, Proxmox is installed, and the GPU is physically present, finish the
passthrough setup in two parts.

On the Proxmox host:

1. Enable IOMMU in GRUB.
2. Load the VFIO modules.
3. Bind the RTX 3060 and its audio function to `vfio-pci`.
4. Reboot the host.
5. Confirm the device address with:

```bash
lspci -nn | grep -iE 'vga|3d|audio'
```

Then update your local `terraform/terraform.tfvars`:

```hcl
vm210_gpu_pci_address = "0000:02:00"
```

Important:

- Leave `vm210_gpu_pci_address` blank until you know the real PCI address.
- The exact Terraform PCI device block depends on the installed `bpg/proxmox`
  provider version and the final host hardware layout.
- This repo intentionally does not guess that block before the host exists.
- When the host is ready, update the `vm210-ai-gpu` module to attach the PCI
  device at that recorded address.

## 12. Verify Ansible can see the hosts

Run:

```bash
./scripts/ansible-ping.sh
```

If this fails, check:

- inventory contents
- host IP addresses
- SSH access
- the configured `ansible_user`
- that your vault password file is available

## 13. Run the full deployment

Run:

```bash
./scripts/deploy-all.sh
```

This will:

- initialize Terraform
- validate Terraform
- apply Terraform
- install Ansible collections
- syntax-check the playbook
- ping all hosts
- run the Ansible site playbook

## 14. Pull the initial Ollama models

After the AI VM stack is up, load the initial coding models into Ollama:

```bash
docker exec -it ollama ollama pull qwen2.5-coder:7b
docker exec -it ollama ollama pull qwen2.5-coder:14b
```

These become available through the Open WebUI API layer.

## 15. Configure the Continue API front door

If you want one consistent API front door and plan to add more providers later,
point Continue at Open WebUI instead of talking directly to Ollama.

Start from:

- [config.yaml.example](/home/ww/HomeLab/HomeLab/continue/config.yaml.example)

This file is a local client-side example for Continue. It is not deployed by
Terraform, Ansible, or Docker Compose.

Example `config.yaml`:

```yaml
name: Homelab Continue
version: 0.0.1
schema: v1

models:
  - name: qwen25coder7b-webui
    provider: openai
    model: qwen2.5-coder:7b
    apiBase: http://10.10.20.250:3000/api
    apiKey: your-open-webui-api-key

  - name: qwen25coder14b-webui
    provider: openai
    model: qwen2.5-coder:14b
    apiBase: http://10.10.20.250:3000/api
    apiKey: your-open-webui-api-key

context:
  - provider: code
  - provider: docs
  - provider: diff
  - provider: terminal
```

Notes:

- replace `10.10.20.250` with the real IP or DNS name for your AI VM
- create and use a real Open WebUI API key after logging into Open WebUI
- this keeps Continue pointed at one OpenAI-compatible endpoint even if you add
  more local or remote providers later

## 16. Add encrypted stack environment files

When a Docker stack needs secrets:

1. create `stack.env.example` with placeholders
2. create `stack.env.vault` encrypted with Ansible Vault
3. commit `stack.env.vault`
4. do not commit the decrypted `stack.env`

Example:

```bash
ansible-vault encrypt ansible/files/compose/lxc220-docker-apps/my-service/stack.env.vault
```

At deploy time, Ansible decrypts `stack.env.vault` and writes `stack.env` onto
the target host.

## 17. Information you may still need to fill in manually

Depending on the environment, you may still need to provide:

- public DNS names
- TLS certificates for the reverse proxy
- VPN credentials for Gluetun-based stacks
- app-specific database passwords and API keys
- Home Assistant, Frigate, Immich, OwnCloud, or WordPress application settings
- GPU passthrough configuration on the Proxmox side for the AI VM
- pfSense interface assignment and final WAN/LAN setup

## Related guides

- [README.md](/home/ww/HomeLab/HomeLab/README.md)
- [README-add-docker-component.md](/home/ww/HomeLab/HomeLab/README-add-docker-component.md)
- [README.md](/home/ww/HomeLab/HomeLab/ansible/README.md)
