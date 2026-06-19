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
5. **pfSense installer image is uploaded** — Download `netgate-installer-v1.1.1-RELEASE-amd64.img` and upload it to Proxmox at `/var/lib/vz/template/iso/`. This must be done **before** continuing the bootstrap.

---

## Quick-start flow

| Step | Script | What it does |
|------|--------|--------------|
| 1 | `./scripts/prepare-proxmox-host.sh` | Packages, repos, vault, SSH key, deploy key |
| 2 | `./scripts/prepare-templates.sh` | Downloads Debian 12 LXC template, verifies VM templates |
| 3 | *(configure tfvars)* | API token, node name, template VMIDs, GPU PCI |
| 3a | *(SSH key setup — optional)* | Adds client SSH key to Proxmox root's authorized_keys |
| 3b | *(Upload pfSense image)* | **REQUIRED** Download and upload `netgate-installer-v1.1.1-RELEASE-amd64.img` to Proxmox `/var/lib/vz/template/iso/` |
| 4 | *(Manual pfSense install)* | VM 100 is pre-created with the Netgate `.img` imported as a boot disk; boot and install pfSense manually |
| 5 | *(Manual pfSense GUI setup)* | See [README-pfsense.md](README-pfsense.md) — configure VLANs, interfaces, firewall rules |
| 6 | `./scripts/terraform-init.sh production` + plan + apply | Creates all VMs and LXCs (excluding pfSense) |
| 7 | `./scripts/fix-lxc-recreate.sh` | LXC post-create + TUN + storage + verify (combines steps 9–12) |
| 7a | `./scripts/proxmox-apply-lxc-postcreate.sh` | LXC nesting, bind mounts (if running manually) |
| 7b | `./scripts/setup-lxc-root-password.sh` | Sets LXC root password (if not already set) |
| 7c | `./scripts/apply-lxc-root-password.sh` | Applies password to rebooted LXCs (if needed) |
| 7d | `./scripts/setup-tun-device.sh` | Adds /dev/net/tun to docker-arr LXC |
| 7e | `./scripts/prepare-lxc-storage.sh` | Creates ZFS bind-mount dirs with 777 perms |
| 8 | `./scripts/move-proxmox-ip.sh` | Moves host IP from vmbr0 to vmbr2.99 |
| 9 | `./scripts/verify-ansible-hosts.sh` | Pings all hosts |
| 10 | `./scripts/deploy-all.sh` | Runs Ansible site playbook |
| 11 | `./scripts/apply-pfsense-config.sh` | Applies pfSense firewall rules |
| 12 | *(GPU passthrough — optional)* | See GPU section below |
| 13 | *(grist-finance-connector — optional)* | See private image section below |

---

## Current operational notes

These notes capture known live deviations discovered during SSH/Ansible repair so
they are not lost between sessions.

- `proxmox-host` management now lives on `10.10.99.110`, not `10.10.99.10`.
- Host-local Ansible is expected to run from the Proxmox node for downstream VLAN
  workloads when the workstation is outside the pfSense-managed path.
- `ai-gpu` uses `ansible_remote_tmp=/var/tmp/ansible-remote` because
  `/tmp/ansible-remote` was previously created as `root` and breaks Ansible's
  remote module staging for the unprivileged `ansible` user.
- The DMZ LXCs (`docker-arr`, `docker-external`) currently depend on a temporary
  Proxmox-host NAT/forwarding workaround because pfSense DMZ gateway
  `10.10.66.1` is not yet providing egress. This is intentionally temporary and
  should be removed once the network is fully moved behind pfSense VLANs.
- `docker-arr` requires `/dev/net/tun` in CT `166` for the `gluetun` container.
- `ai-gpu` requires NVIDIA driver plus NVIDIA Container Toolkit before Compose
  stacks using `gpus: all` can start. The `vm210-ai-gpu` Ansible role now
  installs and configures these automatically. Keep
  `./scripts/install-nvidia-drivers.sh` as a break-glass recovery path.
- Frigate on `ai-gpu` uses the ONNX detector with the Nvidia-capable
  `stable-tensorrt` image. The `vm210-ai-gpu` Ansible role can build a
  Frigate-compatible YOLOv9 ONNX model at
  `/mnt/appdata/configs/frigate/model_cache/yolo.onnx`, which maps to
  `/config/model_cache/yolo.onnx` in the container. The older amd64 TensorRT
  detector path is intentionally not used because Frigate 0.17 rejects it on
  amd64.

---

## Step-by-step detail

### Step 1 -- Prepare the Proxmox host

```bash
./scripts/prepare-proxmox-host.sh
```

This script:

- Configures Proxmox VE 9 no-subscription apt repositories using `.sources`
  entries for the current Debian suite
- Upgrades all packages
- Installs git, ansible, terraform, and build dependencies
- Clones the HomeLab repo to `~/HomeLab`
- Creates the Ansible vault password file (`~/.config/ansible/homelab-vault-pass.txt`)
- Generates an `ed25519` SSH deploy key (if not already present)
- Generates a dedicated Proxmox host guest-access key at `~/.ssh/homelab-bootstrap`
- Writes `terraform/generated/proxmox-host-control.auto.tfvars.json` so Terraform uses that Proxmox host key as the primary guest SSH key and also keeps it as the explicit host-control key
- Publishes bootstrap scripts to `/mnt/appdata/homelab-control/bin/`
- Fixes hostname resolution for `pvecm`/`pct`

**You must** add the displayed public key as a deploy key on your GitHub repo.

If this step upgrades the Proxmox kernel or ZFS packages, reboot the host
before continuing so the running kernel and `zfs-kmod` match.

### Step 2 -- Prepare Proxmox templates

```bash
./scripts/prepare-templates.sh
```

Downloads the Debian 12 standard LXC template and verifies that VM templates
9000 (Ubuntu AI) and 9051 (Linux Mint) exist. If the VM templates don't exist
yet, create them using the reference instructions at the bottom of this guide.

### Step 3 -- Configure Terraform variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and set at minimum:

```hcl
pm_api_url          = "https://10.10.1.10:8006/"
pm_api_token_id     = "root@pam!provider"
pm_api_token_secret = "<secret from pveum command below>"
pm_tls_insecure     = true
proxmox_node        = "pve"
resource_profile    = "balanced_96gb"
vm_template_vmid    = 9000
vm050_mint_template_vmid = 9051
lxc_root_password   = "<same as your Ansible vault password>"
ssh_public_key      = ""
```

If you run the bootstrap from the Proxmox host, `./scripts/prepare-proxmox-host.sh`
also generates `terraform/generated/proxmox-host-control.auto.tfvars.json`.
The Terraform wrapper scripts load that file automatically so guests use the
Proxmox host key as their primary Terraform-injected SSH key and also keep it
as the explicit host-control key for host-local Ansible.

Create the API token:

```bash
pveum user token add root@pam provider --privsep 0
```

### Step 3a -- Set up SSH key authentication (optional)

By default, SSH operations use `sshpass` with the root password. To enable
key-based authentication for future sessions (more secure and convenient):

**On your client machine** (where you run terraform commands):

Ensure your SSH private key is in the default location:

```bash
ls -la ~/.ssh/id_ed25519
```

If it doesn't exist, the Proxmox prepare script should have created it. If you're
using a different identity, use:

```bash
ssh-add ~/.ssh/your_key
```

**On the Proxmox host** (one-time setup):

Run this command from your client to add your public key to the Proxmox root's
`authorized_keys`:

```bash
ssh-keyscan -H 10.10.1.110 >> ~/.ssh/known_hosts 2>/dev/null
ssh-copy-id -i ~/.ssh/id_ed25519 root@10.10.1.110
```

Or manually via password:

```bash
sshpass -p '<root_password>' ssh -o StrictHostKeyChecking=no root@10.10.1.110 \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
   cat >> ~/.ssh/authorized_keys << "KEY"
<your_public_key_from_terraform.tfvars>
KEY
chmod 600 ~/.ssh/authorized_keys && echo "SSH key added"'
```

**Verify** key auth works:

```bash
ssh root@10.10.1.110 "echo SSH key auth works!"
```

After this, all future `ssh` and `scp` commands will use the key instead of
requiring the password.

### Step 3b -- Upload pfSense installer image (REQUIRED)

**This step must be completed before continuing bootstrap.**

Download the pfSense installer image from https://www.netgate.com/downloads/pfsense/ and use the AMD64 `.img` variant.

Upload it to the Proxmox host:

```bash
# From your client machine
scp netgate-installer-v1.1.1-RELEASE-amd64.img root@10.10.1.110:/var/lib/vz/template/iso/

# Or manually on the Proxmox host
wget -O /var/lib/vz/template/iso/netgate-installer-v1.1.1-RELEASE-amd64.img \
  '<download the current Netgate AMD64 IMG URL from your account>'
```

Verify the file is present:

```bash
ssh root@10.10.1.110 'ls -lh /var/lib/vz/template/iso/netgate-installer-v1.1.1-RELEASE-amd64.img'
```

**Do not continue until this file exists.**

### Step 4 -- Manual pfSense install from installer image

VM 100 is pre-created with the pfSense installer image imported as boot media and 4 network interfaces configured:
- `net0`: vmbr0 (bootstrap)
- `net1`: vmbr1 (WAN)
- `net2`: vmbr2 (LAN/trunk)
- `net3`: vmbr3 (DMZ)

Start VM 100 and complete the install:

```bash
ssh root@10.10.1.110 'qm start 100'
```

Use the Proxmox console to complete the pfSense install:
1. Boot from the imported installer disk image (already configured)
2. Choose `UFS` filesystem
3. Complete the FreeBSD/pfSense installation wizard
4. After first boot, configure basic networking (optional CLI setup)

After the installer finishes writing pfSense to `scsi0`, switch the VM to boot
from the installed system disk instead of the imported installer image:

```bash
ssh root@10.10.1.110 'qm stop 100'
ssh root@10.10.1.110 "qm set 100 --boot order='scsi0' --delete sata0"
ssh root@10.10.1.110 'qm start 100'
```

**Do not start Terraform until pfSense is fully installed and you can reach its management interface.**

### Step 5 -- Manual pfSense GUI setup

Follow [README-pfsense.md](README-pfsense.md) to configure:

- Hostname/domain (`pfsense.uk.wrightwells.com`)
- Interface assignment (WAN = `vmbr1`, LAN = `vmbr2`, DMZ = `vmbr3`)
- Management VLAN 99 on the LAN interface (IP `10.10.99.1/24`)
- DHCP scopes, DNS, firewall rules
- pfBlockerNG, Tailscale, PPPoE/OpenVPN as needed

**Verify**: pfSense management is reachable at `10.10.99.1` and routing works
for VLANs 10, 20, and 66.

**Do not proceed to Step 6 until pfSense is fully operational.**

### Step 6 -- Terraform: all VMs and LXCs (except pfSense)

```bash
./scripts/terraform-init.sh production
terraform -chdir=terraform/environments/production validate
./scripts/terraform-plan.sh production
./scripts/terraform-apply.sh production
```

This creates all Docker LXCs, Mint VM, and AI GPU VM. **pfSense (VM 100) is NOT managed by Terraform** and will not be touched.

### Step 7 -- LXC post-create settings

```bash
./scripts/proxmox-apply-lxc-postcreate.sh
```

Applies `nesting=1,keyctl=1` and bind mounts for `/mnt/appdata` and
`/mnt/media_pool`. Reboot any LXCs that were already running.

### Step 8 -- Add TUN device to docker-arr LXC

The ARR stack uses gluetun which requires `/dev/net/tun`:

```bash
./scripts/setup-tun-device.sh
```

This adds the device to LXC 166 and reboots it.

### Step 9 -- Prepare LXC storage directories

Unprivileged LXCs cannot `chown` ZFS bind-mount paths. This script creates all
directories on the Proxmox host with `777` permissions:

```bash
./scripts/prepare-lxc-storage.sh
```

Covers every volume used by the ARR stack, services, apps, media, external, and
infra hosts. This is especially important now that several app/database/state
paths under `/mnt/appdata/docker_volumes` are host bind mounts rather than
Docker-managed named volumes.

### Step 10 -- Move Proxmox host IP to management VLAN

```bash
./scripts/move-proxmox-ip.sh
```

Moves the Proxmox management IP from `10.10.1.10` (vmbr0) to `10.10.99.110`
(vmbr2.99) behind pfSense.

**Your SSH session will disconnect.** Reconnect with:

```bash
ssh root@10.10.99.110
```

### Step 11 -- Verify Ansible can reach all hosts

```bash
./scripts/verify-ansible-hosts.sh
```

Expected output: every host returns `pong`. If pfSense shows `UNREACHABLE`
that's normal — it has its own playbook (step 16).

If guests are reachable from the Proxmox host but not from your workstation,
use the Proxmox host as the control node:

```bash
./scripts/ensure-proxmox-host-ansible.sh
./scripts/run-ansible-on-proxmox-host.sh --limit ai_gpu
```

That fallback matches the way the bootstrap scripts are designed to run: the
Proxmox host owns the repo checkout, vault file, rendered inventory, and the
generated `~/.ssh/homelab-bootstrap` guest-access key.

### Step 12 -- Run Ansible site deploy

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

If you are launching the playbook from your workstation and guest VLANs are not
directly routable from there, prefer the host-local wrapper instead:

```bash
./scripts/ensure-proxmox-host-ansible.sh
./scripts/run-ansible-on-proxmox-host.sh
```

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

# 3. After reboot, update terraform.tfvars with the values printed by the script
#    (PCI address, vendor:device, IOMMU group, and subsystem id)

# 4. Re-apply production Terraform so the provider creates the PCI mapping
#    and attaches the GPU to vm210 in a repeatable way
./scripts/terraform-apply.sh production

# 5. Start vm210 if your resource profile leaves it powered off
ssh root@10.10.99.110 "qm start 210"

# 6. Install NVIDIA drivers and Container Toolkit inside the VM
#    If the guest is only reachable from Proxmox, run from the host:
ssh root@10.10.99.110 "cd /root/HomeLab && ./scripts/run-ansible-on-proxmox-host.sh --limit ai_gpu"
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
| `lxc220-docker-apps` | `10.10.20.220` | Blinko, Calibre, Calibre-Web, EruGo, Firefly III, Grafana, Grist, Homarr, InfluxDB, Node-RED, Pairdrop, Planka, Semaphore, TeslaMate, grist-finance-connector |
| `lxc230-docker-media` | `10.10.20.230` | Jellyfin, Plex, Jellyswarrm |
| `lxc240-docker-external` | `10.10.66.240` | Cloudflare DDNS, Ghost, Kutt, nginx, RustDesk, Tailscale relay, Walletpage, WordPress |
| `lxc250-infra` | `10.10.20.250` | Alertmanager, Grafana, Homebridge, Mosquitto MQTT, Portainer, Prometheus, Semaphore, Uptime Kuma |

---

## Guest IP layout (UK defaults)

| Host | IP | Network |
|------|----|---------|
| Proxmox host (after step 12) | `10.10.99.110` | `vmbr2.99` (management VLAN) |
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

### `appdata` ZFS pool shows `unsupported feature(s)`

If the Proxmox storage playbook or `zpool import` reports
`unsupported feature(s)` for `appdata`, the host is usually still running an
older kernel/ZFS module after package upgrades. Reboot the Proxmox host, then
rerun:

```bash
cd ~/HomeLab/ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-storage.yml
```

The storage role now imports an existing `appdata` pool automatically before it
falls back to destructive first-boot pool creation.

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
4. Verify Terraform variables are set:
   - `vm210_gpu_pci_address`
   - `vm210_gpu_device_id`
   - `vm210_gpu_iommu_group`
   - `vm210_gpu_subsystem_id`
5. Verify VM config: `qm config 210 | grep -i pci`
6. Verify VM uses q35 machine: `qm config 210 | grep machine`

### Guests reachable from Proxmox host but not from your workstation

The approved recovery path is to use the Proxmox host as the Ansible control
node rather than forcing direct workstation-to-guest SSH:

```bash
./scripts/ensure-proxmox-host-ansible.sh
./scripts/run-ansible-on-proxmox-host.sh --limit <host-or-group>
```

This is especially useful while:
- the Proxmox host is still on the bootstrap bridge
- pfSense VLAN routing is only partially configured
- guest VLANs are reachable from the host but not from your local machine

`./scripts/ensure-proxmox-host-ansible.sh` also writes
`terraform/generated/proxmox-host-control.auto.tfvars.json` on the workstation
so future Terraform runs from there seed the same host-control public key into
new guests.

If a VM comes up with a duplicate or unusable service IP during bootstrap,
attach a temporary `vmbr0` NIC, recover it from the Proxmox console, then move
it back to its intended VLAN-backed address before the final Ansible run.

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

### Linux Mint Cinnamon template (for vm050-mint, current VMID 9051)

1. Download the Linux Mint Cinnamon ISO.
2. Create a temporary VM on Proxmox and install Mint.
3. On the Proxmox host, export the same deploy public key that the control-node
   Ansible runs actually use:

```bash
ssh-keygen -y -f /root/.ssh/homelab-bootstrap
```

4. Inside Mint, create the `ansible` account with that exact public key:

```bash
sudo useradd -m -s /bin/bash ansible || true
sudo install -d -m 700 -o ansible -g ansible /home/ansible/.ssh
printf '%s\n' 'ssh-ed25519 AAAA...actual-homelab-bootstrap-key' | sudo tee /home/ansible/.ssh/authorized_keys >/dev/null
sudo chown ansible:ansible /home/ansible/.ssh/authorized_keys
sudo chmod 600 /home/ansible/.ssh/authorized_keys
sudo usermod -aG sudo ansible
printf 'ansible ALL=(ALL) NOPASSWD:ALL\n' | sudo tee /etc/sudoers.d/90-ansible >/dev/null
sudo chmod 440 /etc/sudoers.d/90-ansible
```

5. Install required packages:

```bash
sudo apt update
sudo apt install -y openssh-server qemu-guest-agent cloud-init
sudo systemctl enable ssh qemu-guest-agent
```

6. Make sure the template NIC matches the trusted workstation network:

```bash
qm set 9051 --net0 virtio,bridge=vmbr2,tag=10
qm set 9051 --boot order=scsi0
```

7. Clean cloud-init state before templating:

```bash
sudo cloud-init clean --logs
sudo shutdown now
```

8. Convert to template:

```bash
qm template 9051
```

9. Validate the template with a throwaway clone before using it for Terraform:

```bash
qm clone 9051 9052 --name mint-template-validation
qm set 9052 --ide2 local-lvm:cloudinit --ciuser ansible --cipassword '<bootstrap-password>'
qm set 9052 --sshkeys /root/.ssh/homelab-bootstrap.pub
qm set 9052 --ipconfig0 ip=10.10.10.52/24,gw=10.10.10.1 --nameserver 10.10.10.1
qm start 9052
ssh -i /root/.ssh/homelab-bootstrap ansible@10.10.10.52
```

Expected result:
- SSH works immediately with the deploy key
- `cloud-init status --long` reports `DataSourceNoCloud`
- the clone comes up on the requested static IP

Set `vm050_mint_template_vmid = 9051` in `terraform.tfvars`.

Notes:
- Host-level Tailscale is now installed by the shared Ansible `tailscale` role,
  not preinstalled in the Mint template.
- The desktop NIC may appear as `eth0` or `ens18` depending on the clone; use
  NetworkManager or runtime detection rather than hardcoding the interface name
  in one-off admin commands.

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
