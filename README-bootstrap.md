# Bootstrap Guide

This guide follows the approved 11-step operational flow for building this HomeLab from bare metal to fully configured services.

**Read the full flow first.** Steps are numbered in execution order. Each step is tagged `[MANUAL]` or `[TERRAFORM]` / `[ANSIBLE]` so you can see exactly what is automated and what requires human action.

---

## Approved operational flow

| Step | Description | Driver |
|------|-------------|--------|
| 1 | Proxmox install and base host preparation | [MANUAL] |
| 2 | `/etc/network/interfaces` setup on `vmbr0` | [MANUAL] |
| 3 | Disk creation / storage preparation | [MANUAL / ANSIBLE] |
| 4 | Tailscale on the host, verify SSH over Tailscale | [MANUAL / ANSIBLE] |
| 5 | Terraform pfSense only | [TERRAFORM] |
| 6 | Install and configure pfSense manually | [MANUAL] |
| 7 | Create deployment SSH keypair, publish bootstrap script to `/mnt/appdata` | [MANUAL] |
| 8 | Terraform remaining VMs and LXCs (including Mint) | [TERRAFORM] |
| 9 | Run published SSH bootstrap script on each created machine | [MANUAL] |
| 10 | Move Proxmox host IP from `vmbr0` to `vmbr2` | [MANUAL] |
| 11 | Run Ansible to build/configure VMs and LXCs | [ANSIBLE] |

---

## Step 1 -- Proxmox install and base host preparation `[MANUAL]`

### 1.1 BIOS Configuration

Boot into the Z420 BIOS with `F10` and set:

- Storage:
  - `SATA Mode -> AHCI`
  - disable RAID mode
- Boot:
  - enable UEFI boot
  - disable legacy boot
- Security:
  - `System Security -> Virtualization Technology (VTx) -> Enable`
  - `System Security -> Intel VT-d` or `Virtualization Technology Directed I/O (VTd) -> Enable`
- PCI:
  - `Above 4G decoding -> Enable` if the option exists

Save and reboot.

Exact HP Z420 path for virtualization:

```text
F10 BIOS Setup -> Security -> System Security
```

If a BIOS update is needed, apply it before installing Proxmox, then re-check all settings above.

Why these matter:

- `AHCI` keeps storage simple for the Proxmox OS disk
- `UEFI` matches the recommended modern Proxmox install path
- `VT-x` and `VT-d` are required for virtualization and later GPU passthrough
- `Above 4G decoding` is strongly recommended for PCIe GPU passthrough

### 1.2 Prepare the Proxmox Installer

From another machine, download the latest Proxmox VE ISO:

- <https://www.proxmox.com/en/downloads>

Create a bootable USB on Linux:

```bash
sudo dd if=proxmox-ve_*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### 1.3 Install Proxmox

Boot from the USB installer and use these baseline choices:

- target disk: `500 GB SATA SSD`
- filesystem: `ext4`
- hostname example: `pve01.uk.wrightwells.com`
- management NIC: onboard `1 Gb` NIC

Recommended installer network values:

- UK: IP `10.10.1.10`, gateway `10.10.1.1`, DNS `10.10.1.1`
- France: IP `10.20.1.10`, gateway `10.20.1.1`, DNS `10.20.1.1`

Site-aware rule:

- UK builds use `10.10.x.x`
- France builds use `10.20.x.x`
- VLAN-aware guest addressing follows `10.<site_octet>.<vlan>.<host_id>`

Use `ext4` for the Proxmox OS install disk. Do not use ZFS for the OS disk.

### 1.4 First Host Upgrade

```bash
ssh root@10.10.1.10
```

If not using a Proxmox subscription:

```bash
sed -i 's/^deb/#deb/g' /etc/apt/sources.list.d/pve-enterprise.list
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-sub.list
apt update
apt full-upgrade -y
reboot
```

Install required utilities:

```bash
sudo apt update
sudo apt install -y wget jq unzip pciutils lsblk git curl gnupg software-properties-common python3-pip ansible
```

Install Terraform:

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo ${VERSION_CODENAME}) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y terraform
```

Clone the repo:

```bash
git clone https://github.com/wrightwells/HomeLab.git ~/HomeLab
cd ~/HomeLab
```

Verify:

```bash
git --version
ansible --version
terraform version
```

Identify disks:

```bash
lsblk -o NAME,SIZE,MODEL
```

### 1.5 Switch SSH from Password to Key Authentication

```bash
~/HomeLab/scripts/setup-ssh-key-login.sh --host 10.10.1.10 --user root
```

After key login works, disable password auth in `/etc/ssh/sshd_config`:

```ssh-config
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password
```

Then:

```bash
sshd -t
systemctl restart ssh
```

---

## Step 2 -- `/etc/network/interfaces` on `vmbr0` `[MANUAL]`

Terraform does **not** configure Proxmox host networking. You must create the bridge layout manually.

At this stage the Proxmox host management IP lives on `vmbr0`. Later (step 10) it will move to `vmbr2`, but `vmbr0` remains defined.

### Initial `/etc/network/interfaces` (step 2 -- bring-up on `vmbr0`)

```text
# Loopback
auto lo
iface lo inet loopback

# Physical NICs
auto nic0
iface nic0 inet manual

auto nic1
iface nic1 inet manual

auto nic2
iface nic2 inet manual

# Bootstrap bridge on the Proxmox uplink NIC.
# Proxmox host IP lives here during bring-up.
auto vmbr0
iface vmbr0 inet static
    address 10.10.1.10/24
    gateway 10.10.1.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0

# pfSense WAN bridge on nic1
auto vmbr1
iface vmbr1 inet manual
    bridge-ports nic1
    bridge-stp off
    bridge-fd 0

# pfSense LAN trunk on nic2
# Carries internal VLANs once pfSense is in place
auto vmbr2
iface vmbr2 inet manual
    bridge-ports nic2
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# Optional DMZ / untrusted bridge
auto vmbr3
iface vmbr3 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

Notes:

- Discover real interface names with `ip -br link` and `ip -br addr`. Replace `nic0`/`nic1`/`nic2` with the actual names on your hardware.
- `vmbr0` carries the Proxmox management IP during initial bring-up.
- `vmbr1` is the dedicated pfSense WAN bridge.
- `vmbr2` is the pfSense LAN/trunk bridge for internal VLAN-backed guests.
- `vmbr3` is the separate DMZ segment.
- Apply network changes carefully, especially on a remote host.

---

## Step 3 -- Disk creation / storage preparation `[MANUAL / ANSIBLE]`

Leave disk creation/storage preparation ownership unchanged from the current repo behavior.

If you want Ansible to prepare host storage (NVMe ext4, ZFS mirror appdata, XFS media disks + mergerfs), follow:

- [README-storage.md](README-storage.md)
- [proxmox-storage.yml](ansible/playbooks/proxmox-storage.yml)

Update the real disk IDs in:

- [ansible/inventories/production/group_vars/proxmox.yml](ansible/inventories/production/group_vars/proxmox.yml)

Then run:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-storage.yml
```

After the initial format-and-create run, set:

```yaml
proxmox_storage_allow_destructive_create: false
```

This step creates the shared host directories used by the rest of the lab:

- `/mnt/media_pool/*`
- `/mnt/appdata/docker_volumes`
- `/mnt/appdata/configs`

---

## Step 4 -- Tailscale on the host, verify SSH over Tailscale `[MANUAL / ANSIBLE]`

Run the dedicated Proxmox host Tailscale playbook:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-host.yml
```

This installs Tailscale on the Proxmox host using the vaulted `TS_AUTHKEY` stored in:

- [ansible/files/compose/lxc240-docker-external/tailscale-peer-relay/stack.env.vault](ansible/files/compose/lxc240-docker-external/tailscale-peer-relay/stack.env.vault)

After enrollment, verify SSH access to the Proxmox host over its Tailscale IP:

```bash
ssh root@<tailscale-ip-of-proxmox>
```

This step happens **before** Terraform pfSense (step 5) so you have verified remote access to the host before committing to the staged Terraform flow.

---

## Step 5 -- Terraform pfSense only `[TERRAFORM]`

### 5.1 Create the Proxmox API token

```bash
pveum user token add root@pam provider --privsep 0
```

### 5.2 Configure Terraform variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Set at least:

```hcl
pm_api_url          = "https://YOUR-PROXMOX-IP:8006/api2/json"
pm_api_token_id     = "root@pam!provider"
pm_api_token_secret = "PASTE_NEW_SECRET_HERE"
pm_tls_insecure     = true
proxmox_node        = "littledown"
resource_profile    = "balanced_128gb"
```

### 5.3 Prepare templates

Before running Terraform, make sure Proxmox already has:

- the Debian LXC template (downloaded via `pveam`)
- a prepared Linux Mint Cinnamon VM template (for later use in step 8)
- a prepared Ubuntu Server 24.04 LTS cloud-image template (for the AI VM, later use in step 8)

Debian LXC template:

```bash
pveam update
TEMPLATE=$(pveam available | awk '/debian-12-standard/ {print $2; exit}')
pveam download local "$TEMPLATE"
```

VM template preparation is documented in the "Template preparation reference" section near the end of this guide.

### 5.4 Apply Terraform -- pfSense stage only

The `pfsense` environment creates **pfSense only**. It does **not** create Mint or any other workload.

```bash
./scripts/terraform-init.sh pfsense
terraform -chdir=terraform/environments/pfsense validate
./scripts/terraform-plan.sh pfsense
./scripts/terraform-apply.sh pfsense
```

This creates VM 100 (pfSense) with its four network interfaces attached to `vmbr0` (bootstrap), `vmbr1` (WAN), `vmbr2` (LAN/trunk), and `vmbr3` (DMZ).

---

## Step 6 -- Install and configure pfSense manually `[MANUAL]`

After Terraform creates VM 100:

```bash
# Attach the installer ISO
qm set 100 --ide2 local:iso/netgate-installer-v1.1.1-RELEASE-amd64.iso,media=cdrom

# Boot from CD
qm set 100 --boot order=ide2

# Start the VM
qm start 100
```

Complete the pfSense install in the Proxmox console. Use `UFS` for the filesystem.

After the first installed boot succeeds:

```bash
# Confirm disk
qm config 100

# Restore boot from VM disk
qm set 100 --boot order=scsi0

# Remove the ISO
qm set 100 --delete ide2
```

Then complete the manual pfSense GUI prerequisites:

- [README-pfsense.md](README-pfsense.md)

This includes: hostname/domain, pfBlockerNG, Tailscale, ntopng, PPPoE, PIA OpenVPN, interface assignment, WAN/LAN/DMZ checks.

---

## Step 7 -- Create deployment SSH keypair, publish bootstrap script to `/mnt/appdata` `[MANUAL]`

### 7.1 Generate or confirm the deployment SSH keypair

The repo uses a single `ed25519` keypair for initial machine bootstrap. If you do not already have one:

```bash
ssh-keygen -t ed25519 -C "homelab-deploy" -f ~/.ssh/id_ed25519 -N ""
```

This same public key is passed to all VMs and LXCs via Terraform `ssh_public_key`.

### 7.2 Publish the SSH bootstrap script

The bootstrap script is published to `/mnt/appdata/homelab-control/bin/` so it can be run manually on each created machine.

```bash
./scripts/publish-control-node-bootstrap.sh
```

This copies:

- `bootstrap-control-node.sh` -- clones the repo, installs packages, runs Ansible
- `bootstrap-user-control-node.sh` -- bootstrap from a user home directory
- `fix-mint-apt-repos.sh` -- repairs stale Mint APT sources
- `fix-mint-dpkg.sh` -- repairs interrupted dpkg
- `update-control-node.sh` -- pulls latest repo and re-runs Ansible
- `github-deploy-key` and `github-deploy-key.pub` -- the deployment SSH keypair

### 7.3 What the bootstrap script does on each machine

**For Linux VMs (Mint, AI GPU):**

- the VM already has cloud-init SSH key injection from Terraform
- the bootstrap script is available at `/mnt/appdata/homelab-control/bin/bootstrap-control-node.sh` (mounted via the shared storage)
- running it installs the `ansible` user account, clones the repo, installs Ansible collections, and runs the site playbook
- the `root` user remains accessible via the injected SSH key
- the `ansible` user is created with passwordless sudo for ongoing Ansible use

**For LXCs:**

- LXCs are created with the root password set to the **same plain-text secret as the Ansible vault password value** (see LXC root password section below)
- after creation, the operator logs in as `root` using that password
- the operator then runs `/mnt/appdata/homelab-control/bin/bootstrap-control-node.sh` (or the user-home variant) to prepare the `ansible` user, clone the repo, and install dependencies
- `root` access is required for initial LXC setup and for Docker-in-LXC operations (nesting)
- the `ansible` user is created by the bootstrap script for ongoing Ansible runs

**Access model summary:**

- `root` is used on all LXCs (required for nesting, bind-mounts, Docker operations)
- `root` is used on the Proxmox host
- `ansible` is used on Linux VMs (Mint, AI GPU) for Ansible runs, with passwordless sudo
- `root` remains accessible via SSH key on all machines for emergency access
- privilege escalation (`become: true`) is expected in Ansible playbooks

### 7.4 LXC root password -- explicit tradeoff

**Decision:** LXC root password uses the **same plain-text secret text** as the Ansible vault password value. It does **not** use a hash of the vault value.

**Tradeoff:** This simplifies the operator flow -- the vault password you type for `ansible-vault` is also the initial root password for every LXC. The downside is that compromising the vault password also gives you LXC root access, and rotating the vault password requires manually updating the LXC root passwords to match. This is accepted for this lab because the vault password file is kept private and the lab is not multi-tenant.

To set the LXC root password, the operator should:

1. Decide on the Ansible vault password (e.g. `MyVaultSecret123`)
2. Generate a SHA-512 password hash from that same secret:

```bash
openssl passwd -6 'MyVaultSecret123'
```

(Alternatively, if `mkpasswd` is available: `mkpasswd -m sha-512 'MyVaultSecret123'`.
The `python3 -c "import crypt; ..."` approach no longer works on Python 3.13+
where the `crypt` module was removed.)

3. Place the hash in `ansible/inventories/production/group_vars/lxc_root_passwords.vault.yml` encrypted with Ansible Vault
4. Use the plain-text vault password as the LXC root password when logging in initially

**Important:** The Terraform LXC modules now accept `lxc_root_password` as a variable.
Set it in `terraform.tfvars` to the same plain-text value as your Ansible vault password.
If you need to change the password on already-created LXCs, run the LXC root password
playbook after the production Terraform apply:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/lxc-root-password.yml
```

---

## Step 8 -- Terraform remaining VMs and LXCs (including Mint) `[TERRAFORM]`

The `production` environment creates Mint plus all non-pfSense workloads.

```bash
./scripts/terraform-init.sh production
terraform -chdir=terraform/environments/production validate
./scripts/terraform-plan.sh production
./scripts/terraform-apply.sh production
```

After Terraform creates the LXCs, apply Proxmox root-only post-create settings:

```bash
./scripts/proxmox-apply-lxc-postcreate.sh
```

This applies:

- `nesting=1,keyctl=1`
- bind mounts for `/mnt/appdata`
- bind mounts for `/mnt/media_pool`

If any LXCs were already running, reboot them after that script finishes.

---

## Step 9 -- Run SSH bootstrap script on each created machine `[MANUAL]`

On each newly created VM and LXC, run the published bootstrap script:

```bash
/mnt/appdata/homelab-control/bin/bootstrap-control-node.sh
```

Or for user-home bootstrap on VMs:

```bash
/mnt/appdata/homelab-control/bin/bootstrap-user-control-node.sh
```

This installs packages, clones the repo, sets up the `ansible` user, installs Ansible collections, and runs the site playbook.

For LXCs, log in as `root` first (using the vault-password from step 7.4), then run the bootstrap script.

---

## Step 10 -- Move Proxmox host IP from `vmbr0` to `vmbr2` `[MANUAL]`

After all VMs and LXCs are created and configured, move the Proxmox management IP from the bootstrap bridge (`vmbr0`) to the trusted internal trunk (`vmbr2`).

**Before:** Proxmox management IP is on `vmbr0` (step 2 initial state).
**After:** Proxmox management IP is on `vmbr2` with VLAN tag 99 (management VLAN). `vmbr0` remains defined but no longer carries the host IP.

### Updated `/etc/network/interfaces` (step 10 -- after move)

```text
# Loopback
auto lo
iface lo inet loopback

# Physical NICs
auto nic0
iface nic0 inet manual

auto nic1
iface nic1 inet manual

auto nic2
iface nic2 inet manual

# Bootstrap bridge -- remains defined but no longer carries the host IP.
# Kept present for legacy/template VM access if needed.
auto vmbr0
iface vmbr0 inet manual
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0

# pfSense WAN bridge on nic1
auto vmbr1
iface vmbr1 inet manual
    bridge-ports nic1
    bridge-stp off
    bridge-fd 0

# pfSense LAN trunk on nic2
# Proxmox host management IP now lives here on VLAN 99
auto vmbr2
iface vmbr2 inet manual
    bridge-ports nic2
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# Proxmox host management interface on vmbr2, VLAN 99
auto vmbr2.99
iface vmbr2.99 inet static
    address 10.10.99.10/24
    gateway 10.10.99.1

# Optional DMZ / untrusted bridge
auto vmbr3
iface vmbr3 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

Notes:

- The gateway `10.10.99.1` is now the pfSense management interface on VLAN 99.
- `vmbr0` remains defined as a plain bridge on `nic0` but carries no host IP.
- Apply carefully -- a mistake here will lose SSH access to the Proxmox host.
- Use the Proxmox console or Tailscale as a fallback if the network change breaks SSH.

---

## Step 11 -- Run Ansible to build/configure VMs and LXCs `[ANSIBLE]`

### 11.1 Verify Ansible can see the hosts

```bash
./scripts/ansible-ping.sh
```

### 11.2 Run the full deployment

```bash
./scripts/deploy-all.sh
```

Or run manually:

```bash
./scripts/ansible-install.sh
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml
```

### 11.3 Apply pfSense configuration

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/pfsense.yml
```

### 11.4 Pull the initial Ollama models

After the AI VM stack is up:

```bash
docker exec -it ollama ollama pull qwen3:8b
docker exec -it ollama ollama pull qwen3:4b
docker exec -it ollama ollama pull qwen2.5-coder:7b
docker exec -it ollama ollama pull qwen2.5vl:7b
docker exec -it ollama ollama pull qwen3-vl:4b
```

---

## GPU passthrough discovery `[LATER -- after step 8, before AI VM GPU use]`

GPU PCI passthrough address discovery happens **after** the production Terraform apply (step 8) has created VM 210, and **before** you expect the AI VM to use the GPU.

This is a Proxmox host preparation step:

1. After step 8, on the Proxmox host run:

```bash
lspci -nn | grep -iE 'vga|3d|audio'
```

2. Record the GPU function address (not the audio function). Example: `01:00.0`.
3. Convert to Proxmox PCI form: `01:00.0` becomes `0000:01:00`.
4. Enable IOMMU in GRUB, load VFIO modules, bind the GPU, and reboot the host.
5. Update `terraform/terraform.tfvars`:

```hcl
vm210_gpu_pci_address = "0000:01:00"
```

6. Re-run the production Terraform apply to attach the GPU to VM 210.

Do **not** guess the PCI address before the host is built. Discover it on the real hardware after the production stage has created the AI VM context.

---

## Template preparation reference

### Ubuntu Server 24.04 LTS cloud-image template (for AI VM)

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

### Linux Mint Cinnamon template (for vm050-mint)

1. Download the Linux Mint Cinnamon ISO.
2. Create a temporary VM on Proxmox and install Mint.
3. Inside Mint, create the `ansible` account:

```bash
sudo useradd -m -s /bin/bash ansible || true
sudo install -d -m 700 -o ansible -g ansible /home/ansible/.ssh
printf '%s\n' 'ssh-ed25519 AAAA...' | sudo tee /home/ansible/.ssh/authorized_keys >/dev/null
sudo chown ansible:ansible /home/ansible/.ssh/authorized_keys
sudo chmod 600 /home/ansible/.ssh/authorized_keys
sudo usermod -aG sudo ansible
printf 'ansible ALL=(ALL) NOPASSWD:ALL\n' | sudo tee /etc/sudoers.d/90-ansible >/dev/null
sudo chmod 440 /etc/sudoers.d/90-ansible
```

4. Install Tailscale, RustDesk, qemu-guest-agent:

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

Create on the machine where you run Ansible:

```bash
mkdir -p ~/.config/ansible
printf '%s\n' 'REPLACE_WITH_YOUR_VAULT_PASSWORD' > ~/.config/ansible/homelab-vault-pass.txt
chmod 600 ~/.config/ansible/homelab-vault-pass.txt
```

This same plain-text value is used as the LXC root password (see step 7.4).

---

## Current guest IP layout (UK defaults)

| Host | IP | Network |
|------|----|---------|
| Proxmox host (step 2) | `10.10.1.10` | `vmbr0` (bootstrap) |
| Proxmox host (step 10) | `10.10.99.10` | `vmbr2.99` (management VLAN) |
| `vm100_pfsense` | `10.10.1.110` | `vmbr0` (bootstrap), plus pfSense-side interfaces on `vmbr1`/`vmbr2`/`vmbr3` |
| `vm050_mint` | `10.10.10.50` | `vmbr2` VLAN 10 |
| `vm210_ai_gpu` | `10.10.20.210` | `vmbr2` VLAN 20 |
| `lxc066_docker_arr` | `10.10.66.66` | `vmbr3` (DMZ) |
| `lxc200_docker_services` | `10.10.20.200` | `vmbr2` VLAN 20 |
| `lxc220_docker_apps` | `10.10.20.220` | `vmbr2` VLAN 20 |
| `lxc230_docker_media` | `10.10.20.230` | `vmbr2` VLAN 20 |
| `lxc240_docker_external` | `10.10.66.240` | `vmbr3` (DMZ) |
| `lxc250_infra` | `10.10.20.250` | `vmbr2` VLAN 20 |

---

## Network intent

- `vmbr0` is the bootstrap/install bridge on the Proxmox uplink. It remains defined after the host IP moves to `vmbr2`.
- `vmbr1` is the pfSense WAN bridge.
- `vmbr2` is the trusted internal trunk (VLAN-aware).
- `vmbr3` is the DMZ-style network for isolated workloads.
- VLAN 99 = management, VLAN 10 = workstation, VLAN 20 = servers, VLAN 66 = DMZ.
- External exposure and NAT are handled in pfSense, not Terraform.

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
