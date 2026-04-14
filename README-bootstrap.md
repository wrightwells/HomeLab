# Bootstrap Guide

This guide takes you from a freshly installed Proxmox host with storage prepared
to a fully deployed HomeLab with all services running.

Every step is a **script** you run from the Proxmox host. Manual steps are
explicitly marked and kept to a minimum.

---

## Prerequisites

Before starting:

1. **Proxmox VE is installed** on the 500 GB SATA SSD with `ext4`.
2. **Storage is prepared** — run the storage playbook per
   [README-storage.md](README-storage.md) so that `/mnt/appdata`,
   `/mnt/media_pool`, and `/mnt/ai_models` exist.
3. **The repo is cloned** to `~/HomeLab` on the Proxmox host.
4. **You know your real NIC names** — discover them with `ip -br link`. Replace
   `nic0`/`nic1`/`nic2` in `/etc/network/interfaces` accordingly.

---

## Quick-start flow

| Step | Script | What it does |
|------|--------|--------------|
| 1 | `./scripts/prepare-proxmox-host.sh` | Packages, repos, vault, SSH key, deploy key |
| 2 | `./scripts/prepare-templates.sh` | Downloads Debian 12 LXC template, verifies VM templates |
| 3 | *(configure tfvars)* | API token, node name, template VMIDs, GPU PCI |
| 4 | `./scripts/terraform-init.sh pfsense` + plan + apply | Creates pfSense VM |
| 5 | *(manual pfSense install)* | Attach ISO, install, detach ISO |
| 6 | *(manual pfSense GUI setup)* | See README-pfsense.md |
| 7 | `./scripts/terraform-init.sh production` + plan + apply | Creates all other VMs and LXCs |
| 8 | `./scripts/fix-lxc-recreate.sh` | LXC post-create + TUN + storage + verify (combines steps 9–12) |
| 8a | `./scripts/proxmox-apply-lxc-postcreate.sh` | LXC nesting, bind mounts (if running manually) |
| 8b | `./scripts/setup-lxc-root-password.sh` | Sets LXC root password (if not already set) |
| 8c | `./scripts/apply-lxc-root-password.sh` | Applies password to rebooted LXCs (if needed) |
| 8d | `./scripts/setup-tun-device.sh` | Adds /dev/net/tun to docker-arr LXC |
| 8e | `./scripts/prepare-lxc-storage.sh` | Creates ZFS bind-mount dirs with 777 perms |
| 9 | `./scripts/move-proxmox-ip.sh` | Moves host IP from vmbr0 to vmbr2.99 |
| 10 | `./scripts/verify-ansible-hosts.sh` | Pings all hosts |
| 11 | `./scripts/deploy-all.sh` | Runs Ansible site playbook |
| 12 | `./scripts/apply-pfsense-config.sh` | Applies pfSense firewall rules |
| 17 | *(GPU passthrough — optional)* | See GPU section below |
| 18 | *(grist-finance-connector — optional)* | See private image section below |

---

## Step-by-step detail

### Step 1 -- Prepare the Proxmox host

```bash
./scripts/prepare-proxmox-host.sh
```

This script:

- Configures no-subscription apt repositories
- Upgrades all packages
- Installs git, ansible, terraform, and build dependencies
- Clones the HomeLab repo to `~/HomeLab`
- Creates the Ansible vault password file (`~/.config/ansible/homelab-vault-pass.txt`)
- Generates an `ed25519` SSH deploy key (if not already present)
- Publishes bootstrap scripts to `/mnt/appdata/homelab-control/bin/`
- Fixes hostname resolution for `pvecm`/`pct`

**You must** add the displayed public key as a deploy key on your GitHub repo.

### Step 2 -- Prepare Proxmox templates

```bash
./scripts/prepare-templates.sh
```

Downloads the Debian 12 standard LXC template and verifies that VM templates
9000 (Ubuntu AI) and 9050 (Linux Mint) exist. If the VM templates don't exist
yet, create them using the reference instructions at the bottom of this guide.

### Step 3 -- Configure Terraform variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and set at minimum:

```hcl
pm_api_url          = "https://10.10.1.10:8006/api2/json"
pm_api_token_id     = "root@pam!provider"
pm_api_token_secret = "<secret from pveum command below>"
pm_tls_insecure     = true
proxmox_node        = "pve01"
resource_profile    = "balanced_64gb"
vm_template_vmid    = 9000
vm050_mint_template_vmid = 9050
lxc_root_password   = "<same as your Ansible vault password>"
ssh_public_key      = "<contents of ~/.ssh/id_ed25519.pub>"
```

Create the API token:

```bash
pveum user token add root@pam provider --privsep 0
```

### Step 4 -- Terraform: pfSense only

```bash
./scripts/terraform-init.sh pfsense
terraform -chdir=terraform/environments/pfsense validate
./scripts/terraform-plan.sh pfsense
./scripts/terraform-apply.sh pfsense
```

This creates VM 100 (pfSense) with four NICs on `vmbr0`/`vmbr1`/`vmbr2`/`vmbr3`.

### Step 5 -- Manual pfSense install

```bash
# Attach the installer ISO
qm set 100 --ide2 local:iso/netgate-installer-v1.1.1-RELEASE-amd64.iso,media=cdrom

# Boot from CD
qm set 100 --boot order=ide2

# Start the VM
qm start 100
```

Use the Proxmox console to complete the pfSense install (`UFS` filesystem).

After first boot:

```bash
# Confirm disk layout
qm config 100

# Restore boot from VM disk
qm set 100 --boot order=scsi0

# Remove the ISO
qm set 100 --delete ide2
```

### Step 6 -- Manual pfSense GUI setup

Follow [README-pfsense.md](README-pfsense.md) to configure:

- Hostname/domain (`pfsense.uk.wrightwells.com`)
- Interface assignment (WAN = `vmbr1`, LAN = `vmbr2`, DMZ = `vmbr3`)
- Management VLAN 99 on the LAN interface (IP `10.10.99.1/24`)
- DHCP scopes, DNS, firewall rules
- pfBlockerNG, Tailscale, PPPoE/OpenVPN as needed

**Verify**: pfSense management is reachable at `10.10.99.1` and routing works
for VLANs 10, 20, and 66.

### Step 7 -- LXC root password

```bash
./scripts/setup-lxc-root-password.sh
```

Prompts for the vault password and creates the encrypted vault file and updates
`terraform.tfvars`. This must run **before** Terraform creates the LXCs.

If LXCs were already created, run this after step 8:

```bash
./scripts/apply-lxc-root-password.sh
```

### Step 8 -- Terraform: all remaining VMs and LXCs

```bash
./scripts/terraform-init.sh production
terraform -chdir=terraform/environments/production validate
./scripts/terraform-plan.sh production
./scripts/terraform-apply.sh production
```

### Step 9 -- LXC post-create settings

```bash
./scripts/proxmox-apply-lxc-postcreate.sh
```

Applies `nesting=1,keyctl=1` and bind mounts for `/mnt/appdata` and
`/mnt/media_pool`. Reboot any LXCs that were already running.

### Step 10 -- Add TUN device to docker-arr LXC

The ARR stack uses gluetun which requires `/dev/net/tun`:

```bash
./scripts/setup-tun-device.sh
```

This adds the device to LXC 166 and reboots it.

### Step 11 -- Prepare LXC storage directories

Unprivileged LXCs cannot `chown` ZFS bind-mount paths. This script creates all
directories on the Proxmox host with `777` permissions:

```bash
./scripts/prepare-lxc-storage.sh
```

Covers every volume used by the ARR stack, services, apps, media, external, and
infra hosts.

### Step 12 -- Move Proxmox host IP to management VLAN

```bash
./scripts/move-proxmox-ip.sh
```

Moves the Proxmox management IP from `10.10.1.10` (vmbr0) to `10.10.99.10`
(vmbr2.99) behind pfSense.

**Your SSH session will disconnect.** Reconnect with:

```bash
ssh root@10.10.99.10
```

### Step 13 -- Verify Ansible can reach all hosts

```bash
./scripts/verify-ansible-hosts.sh
```

Expected output: every host returns `pong`. If pfSense shows `UNREACHABLE`
that's normal — it has its own playbook (step 16).

### Step 14 -- Run Ansible site deploy

```bash
./scripts/deploy-all.sh
```

Or manually:

```bash
./scripts/ansible-install.sh
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml
```

This deploys Docker and all compose stacks to every LXC and VM.

### Step 15 -- Apply pfSense firewall rules

```bash
./scripts/apply-pfsense-config.sh
```

Pushes firewall rules, aliases, and NAT from `pfsense_firewall.yml`.

### Step 16 -- GPU passthrough (optional)

After the AI VM exists, pass the GPU through to it:

```bash
# 1. Discover GPU and set up IOMMU/VFIO
./scripts/setup-gpu-passthrough.sh

# 2. Reboot the Proxmox host
reboot

# 3. After reboot, update terraform.tfvars with the PCI address
#    (the script prints the correct value)

# 4. Configure the VM with GPU passthrough
ssh root@10.10.99.10 "qm set 210 --hostpci0 '0000:06:00,pcie=1,rombar=1,x-vga=1'"
ssh root@10.10.99.10 "qm set 210 --machine q35"

# 5. Start the AI VM
ssh root@10.10.99.10 "qm start 210"

# 6. Install NVIDIA drivers and Container Toolkit inside the VM
ssh ansible@10.10.20.210 'bash -s' < scripts/install-nvidia-drivers.sh

# 7. Reboot the AI VM, then re-run the Ansible AI GPU role
ssh root@10.10.99.10 "qm reboot 210"
# After reboot:
cd ~/HomeLab/ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml --limit ai_gpu
```

### Step 17 -- Private Docker images (optional)

The `grist-finance-connector` is a private image built from a Dockerfile in the
repo. Build and load it with:

```bash
./scripts/load-grist-finance-connector.sh
```

Then ensure it's enabled in `build_inventory.yml` and re-run the site playbook:

```bash
cd ~/HomeLab/ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml --limit docker_apps
```

---

## Deployed services summary

After a successful run, these services are running:

| Host | IP | Services |
|------|----|----------|
| `vm210-ai-gpu` | `10.10.20.210` | Ollama, Open WebUI, Frigate, Home Assistant, Home Assistant Voice, n8n, OpenVSCode Server |
| `vm300-openclaw` | `10.10.66.70` | OpenClaw Gateway (Telegram bot, remote Ollama), Open WebUI |
| `lxc066-docker-arr` | `10.10.66.66` | gluetun, qbittorrent, prowlarr, sonarr, radarr, lidarr, bazarr, readarr, filebrowser, jellyseerr, aurrar |
| `lxc200-docker-services` | `10.10.20.200` | Immich, ownCloud, Paperless-ngx, Syncthing |
| `lxc220-docker-apps` | `10.10.20.220` | Blinko, Calibre, Calibre-Web, EruGo, Firefly III, Grafana, Grist, Homarr, InfluxDB, Node-RED, Pairdrop, Semaphore, TeslaMate, grist-finance-connector |
| `lxc230-docker-media` | `10.10.20.230` | Jellyfin, Plex, Jellyswarrm |
| `lxc240-docker-external` | `10.10.66.240` | Cloudflare DDNS, Ghost, Kutt, nginx, RustDesk, Tailscale relay, Walletpage, WordPress |
| `lxc250-infra` | `10.10.20.250` | Alertmanager, Grafana, Homebridge, Mosquitto MQTT, Portainer, Prometheus, Semaphore, Uptime Kuma |

---

## Guest IP layout (UK defaults)

| Host | IP | Network |
|------|----|---------|
| Proxmox host (after step 12) | `10.10.99.10` | `vmbr2.99` (management VLAN) |
| `vm100_pfsense` | `10.10.99.1` | management VLAN 99 (pfSense IS the gateway) |
| `vm050_mint` | `10.10.10.50` | `vmbr2` VLAN 10 |
| `vm210_ai_gpu` | `10.10.20.210` | `vmbr2` VLAN 20 |
| `vm300_openclaw` | `10.10.66.70` | `vmbr3` (DMZ) |
| `lxc066_docker_arr` | `10.10.66.66` | `vmbr3` (DMZ) |
| `lxc200_docker_services` | `10.10.20.200` | `vmbr2` VLAN 20 |
| `lxc220_docker_apps` | `10.10.20.220` | `vmbr2` VLAN 20 |
| `lxc230_docker_media` | `10.10.20.230` | `vmbr2` VLAN 20 |
| `lxc240_docker_external` | `10.10.66.240` | `vmbr3` (DMZ) |
| `lxc250_infra` | `10.10.20.250` | `vmbr2` VLAN 20 |

---

## Network intent

| Bridge | NIC | Purpose |
|--------|-----|---------|
| `vmbr0` | `nic0` | Bootstrap / temporary access. Remains defined but carries no host IP after step 12. |
| `vmbr1` | `nic1` | pfSense WAN (dedicated) |
| `vmbr2` | `nic2` | pfSense LAN trunk — VLAN-aware, carries VLANs 10, 20, 99 |
| `vmbr3` | — | DMZ / untrusted bridge for isolated workloads |

VLAN 99 = management, VLAN 10 = workstation, VLAN 20 = servers, VLAN 66 = DMZ.

External exposure and NAT are handled in pfSense, not Terraform.

---

## Troubleshooting

### Hostname resolution for Proxmox cluster tools

If `pvecm`, `pct`, or `pvesh` fail with "address lookup" errors:

```bash
./scripts/fix-hostname-resolution.sh
```

### ZFS bind-mount permission denied in LXCs

Unprivileged LXCs map host root to `nobody`. All directories under
`/mnt/appdata` and `/mnt/ai_models` must be created on the **Proxmox host**
with `chmod 777`. Run:

```bash
./scripts/prepare-lxc-storage.sh
```

### Docker compose plugin not found on Debian LXCs

The Docker role now installs the official Docker apt repository on Debian LXCs
which provides `docker-compose-plugin`. If a LXC was created before this fix:

```bash
cd ~/HomeLab/ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml --limit <host>
```

### Vault decryption errors for stack.env.vault files

The vault files must be encrypted with the same password as
`~/.config/ansible/homelab-vault-pass.txt`. If you changed the vault password,
re-encrypt all vault files:

```bash
./scripts/recreate-stack-vaults.sh
```

### GPU not visible in AI VM

1. Verify IOMMU is enabled: `cat /proc/cmdline | grep intel_iommu`
2. Verify VFIO is loaded: `lsmod | grep vfio`
3. Verify GPU is bound to VFIO: `lspci -nnk -s 06:00.0`
4. Verify VM config: `qm config 210 | grep -i pci`
5. Verify VM uses q35 machine: `qm config 210 | grep machine`

---

## Template preparation reference

### Ubuntu Server 24.04 LTS cloud-image template (for AI VM, VMID 9000)

```bash
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

qm create 9000 --name ubuntu-2404-ai-template --memory 4096 --cores 4 --net0 virtio,bridge=vmbr0
qm importdisk 9000 /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

Set `vm_template_vmid = 9000` in `terraform.tfvars`.

### Linux Mint Cinnamon template (for vm050-mint, VMID 9050)

1. Download the Linux Mint Cinnamon ISO.
2. Create a temporary VM on Proxmox and install Mint.
3. Inside Mint, create the `ansible` account:

```bash
sudo useradd -m -s /bin/bash ansible || true
sudo install -d -m 700 -o ansible -g ansible /home/ansible/.ssh
printf '%s\n' 'ssh-ed25519 AAAA...homelab-deploy' | sudo tee /home/ansible/.ssh/authorized_keys >/dev/null
sudo chown ansible:ansible /home/ansible/.ssh/authorized_keys
sudo chmod 600 /home/ansible/.ssh/authorized_keys
sudo usermod -aG sudo ansible
printf 'ansible ALL=(ALL) NOPASSWD:ALL\n' | sudo tee /etc/sudoers.d/90-ansible >/dev/null
sudo chmod 440 /etc/sudoers.d/90-ansible
```

4. Install required packages:

```bash
sudo apt update
sudo apt install -y openssh-server qemu-guest-agent cloud-init
sudo systemctl enable ssh qemu-guest-agent
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable tailscaled
```

5. Shut down and convert to template:

```bash
qm set 9050 --net0 virtio,bridge=vmbr2
qm set 9050 --boot order=scsi0
qm template 9050
```

Set `vm050_mint_template_vmid = 9050` in `terraform.tfvars`.

---

## Ansible vault password file

Created automatically by `./scripts/prepare-proxmox-host.sh`.

Manual creation:

```bash
mkdir -p ~/.config/ansible
printf '%s\n' '<your-vault-password>' > ~/.config/ansible/homelab-vault-pass.txt
chmod 600 ~/.config/ansible/homelab-vault-pass.txt
```

**This same plain-text value is used as the LXC root password.**

---

## Related guides

- [README.md](README.md)
- [README-pfsense.md](README-pfsense.md)
- [README-storage.md](README-storage.md)
- [README-networking.md](README-networking.md)
- [README-services.md](README-services.md)
- [README-build-inventory.md](README-build-inventory.md)
- [README-add-docker-component.md](README-add-docker-component.md)
- [README-semaphore.md](README-semaphore.md)
- [README-stack-env-vaults.md](README-stack-env-vaults.md)
- [README-private-docker-images.md](README-private-docker-images.md)
- [README-sizing.md](README-sizing.md)
- [Terraform Corrections](docs/terraform-corrections.md)
