# Bootstrap Guide

## 0. Bare Metal to Proxmox Install

Use this section only for the very first install on the physical host.

### 0.1 BIOS Configuration

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

Save the changes and reboot.

Exact HP Z420 path for virtualization:

```text
F10 BIOS Setup -> Security -> System Security
```

Then set:

- `Virtualization Technology (VTx) -> Enable`
- `Intel VT-d` or `Virtualization Technology Directed I/O (VTd) -> Enable`

Step-by-step:

1. Reboot the Z420.
2. Tap `F10` as it starts to enter BIOS Setup.
3. Go to `Security`.
4. Open `System Security`.
5. Enable `Virtualization Technology (VTx)`.
6. Then enable `Intel VT-d` if it appears. On HP workstations, enabling `VTx` can make the `VT-d` option appear in the same menu.
7. Press `F10` to save and exit.

Before continuing, also check whether the Z420 is already on a reasonably
current BIOS version. Older workstation BIOS revisions can affect `VT-d`,
PCIe behavior, and GPU passthrough stability.

If a BIOS update is needed:

- download the latest HP Z420 BIOS update from HP's support site on another machine
- follow HP's recommended update method for the Z420, usually from a bootable USB or HP firmware update media
- complete the BIOS update before installing Proxmox
- re-enter BIOS afterward and re-check the settings above, because firmware updates can reset them

Why these matter:

- `AHCI` keeps the storage setup simple for the Proxmox OS disk
- `UEFI` matches the recommended modern Proxmox install path
- `VT-x` and `VT-d` are required for virtualization and later GPU passthrough
- `Above 4G decoding` is strongly recommended for PCIe GPU passthrough

### 0.2 Prepare the Proxmox Installer

From another machine, download the latest Proxmox VE ISO:

- <https://www.proxmox.com/en/downloads>

Create a bootable USB on Linux:

```bash
sudo dd if=proxmox-ve_*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with the correct USB device before running the command.

### 0.3 Install Proxmox

Boot from the USB installer and use these baseline choices:

- target disk: `500 GB SATA SSD`
- filesystem: `ext4`
- hostname example: `pve01.uk.wrightwells.com`
- management NIC: onboard `1 Gb` NIC

Recommended installer network values for this repo:

- UK default IP: `10.10.1.10`
- UK default gateway: `10.10.1.1`
- UK default DNS: `10.10.1.1`

Site-aware rule:

- UK builds use `10.10.x.x`
- France builds use `10.20.x.x`
- VLAN-aware guest addressing follows `10.<site_octet>.<vlan>.<host_id>`

After install, the Proxmox web UI should be reachable at:

- `https://10.10.1.10:8006`

Recommended Proxmox hostname pattern:

- `pve01.uk.wrightwells.com`
- `pve01.fr.wrightwells.com`

If you later add more Proxmox nodes at a site:

- `pve02.uk.wrightwells.com`
- `pve02.fr.wrightwells.com`

Why this works well:

- `pve` identifies the role immediately
- `01` leaves room for clustering or additional hosts later
- the site is explicit
- it fits your real domains better than a placeholder like `.local`

Use `ext4` for the Proxmox OS install disk. Do not use ZFS for the OS disk in
this build, because the repo's storage plan uses:

- `ext4` for the AI NVMe
- a separate `ZFS mirror` for appdata
- `xfs` plus `mergerfs` for media disks

### 0.4 First Host Upgrade

SSH to the new Proxmox host:

```bash
ssh root@10.10.1.10
```

If you are not using a Proxmox subscription, disable the enterprise repo and
enable the no-subscription repo:

```bash
sed -i 's/^deb/#deb/g' /etc/apt/sources.list.d/pve-enterprise.list
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-sub.list
apt update
apt full-upgrade -y
reboot
```

### 0.5 Switch SSH from Password to Key Authentication

Once you have one working password-based SSH session to the Proxmox host, set
up key-based login from your client before you rely on VS Code Remote SSH.

From the client machine, run:

```bash
~/HomeLab/scripts/setup-ssh-key-login.sh --host 10.10.1.10 --user root
```

The script:

- creates an `ed25519` SSH key at `~/.ssh/id_ed25519` if needed
- copies the public key to the server account's `~/.ssh/authorized_keys` using password authentication
- prints the exact key-login test command to run next

After the script finishes, verify key-based login works:

```bash
ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes root@10.10.1.10
```

Only after that succeeds, disable password-based SSH on the server by updating
`/etc/ssh/sshd_config` and any active files under `/etc/ssh/sshd_config.d/`:

```ssh-config
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password
```

Then validate and reload SSH:

```bash
sshd -t
systemctl restart ssh
```

Keep your current server console or password-authenticated session open until
you confirm the key-based login works from a fresh client terminal.

### 0.6 Connect from Another Machine with VS Code

After SSH access is working to the Proxmox host, you can connect from another
machine with VS Code so you can run Terraform and Ansible from this repo more
comfortably and use Codex to help diagnose first-run issues.

Recommended workflow:

1. Install VS Code on your workstation.
2. Install the `Remote - SSH` extension in VS Code.
3. Verify SSH access from your workstation:

```bash
ssh root@10.10.1.10
```

4. In VS Code, run `Remote-SSH: Connect to Host...`
5. Connect to:

```text
root@10.10.1.10
```

6. Open the repo on the Proxmox host:

```text
~/HomeLab
```

This lets you:

- run Terraform directly on the Proxmox host where the tooling is installed
- run Ansible from the same checked-out repo
- use Codex in the connected workspace to inspect files, fix config issues, and
  help diagnose first-run failures

This is especially useful on the first build when you may need to:

- inspect Terraform validation or apply failures
- review generated inventory files
- check Ansible syntax or task failures
- compare the live host state with the repo configuration

### 0.7 Identify the Disks

After reboot, confirm the disks before running any storage bootstrap:

```bash
lsblk -o NAME,SIZE,MODEL
```

You should see the OS SSD plus the NVMe and data disks you expect. Confirm the
real device names and, later, prefer `/dev/disk/by-id/...` values when filling
in the storage variables.

This guide walks through the initial setup of this repo on a host that now has:

- Proxmox VE installed

First install Terraform, Ansible, and Git on a Proxmox VE host:

```bash
sudo apt update
sudo apt install -y git curl gnupg software-properties-common python3-pip ansible

wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo ${VERSION_CODENAME}) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y terraform

git clone https://github.com/wrightwells/HomeLab.git ~/HomeLab
cd ~/HomeLab
```

Verify:

```bash
git --version
ansible --version
terraform version
```

Recommended Proxmox host preflight before you start the build:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y wget jq unzip pciutils lsblk
```

Why these help:

- `apt full-upgrade` brings the Proxmox host fully up to date before you build on top of it
- `wget` is used for cloud image downloads
- `jq` is useful for API troubleshooting
- `unzip` is commonly useful for downloaded tooling and archives
- `pciutils` provides `lspci` for GPU passthrough discovery
- `lsblk` is useful for checking storage devices before the storage bootstrap

If the host kernel or core Proxmox packages change during the upgrade, reboot
the Proxmox host before continuing.

## 1. Choose The Build Shape

Before running Terraform or Ansible, review
[build_inventory.yml](ansible/inventories/production/build_inventory.yml).

Also review
[site_config.yml](ansible/inventories/production/site_config.yml) for the active site.

This file lets you choose:

- which guests are included in the build
- which Docker bundles are enabled per guest
- which logical storage mounts are expected
- whether `appdata`, `media`, `ai_models`, or `ai_cache` use dedicated storage
  or fall back to `host_os`

The site config file controls:

- UK vs France build selection
- the domain suffix such as `uk.wrightwells.com` or `fr.wrightwells.com`
- the second IP octet, for example `10.10.x.x` vs `10.20.x.x`
- VLAN-backed subnet ranges used by Terraform, pfSense, and generated inventory

Use this to describe reduced builds as well as the full target design.

Example:

- early lightweight build: `vm100_pfsense` plus only the guests you need
- reduced disk build: keep `/mnt/appdata` enabled but let it fall back to `host_os`
- later expansion: switch `appdata` or `ai_fast` to dedicated stores without changing guest names or service names

Optional Community Scripts preflight:

- Recommended: Proxmox VE Post Install
- Optional later: CPU Scaling Governor
- Not recommended for this repo: Community Scripts app/LXC/VM installer scripts for services that this repo already manages with Terraform and Ansible

Recommended Community Script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

Why it helps:

- checks and corrects Proxmox package sources
- can disable the enterprise repo if you are not using a subscription
- can enable the no-subscription repo
- can update the host cleanly before you build on top of it

Optional later, after the system is stable:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/scaling-governor.sh)"
```

Use that only if you want to tune power or performance behavior after the
baseline build is complete.

Do not use Community Scripts to install application LXCs or service VMs for
this repo's workloads, because this repo already defines those resources and
their configuration.

It assumes:

- the onboard NIC is your Proxmox management connection
- that management network is connected to a router at `10.10.1.1`
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
  - VM disks, recommended: `local-lvm`
  - LXC root filesystems, recommended: `local-lvm`
  - cloud-init disks, recommended: `local-lvm`
- the VMID of the prepared Ubuntu Server 24.04 LTS VM template clone source
- the RTX 3060 PCI address later, after the host is built, for example `0000:02:00`
- confirm the Debian 12 standard LXC template exists at the expected Proxmox path, or note the actual path if it differs
- your Ansible SSH public key
- your Ansible vault password

## 2. Configure the Proxmox host network manually

Terraform in this repo does not configure the Proxmox host networking or write
`/etc/network/interfaces`. You must create the host NIC and bridge layout
manually first. Terraform only attaches VMs and LXCs to bridges that already
exist in Proxmox.

Use `nic0` for the Proxmox host uplink and keep a bridge on that same physical
port so temporary installer VMs can share internet access during the bootstrap
phase. In the steady state, that bootstrap bridge can remain unused.

Example `/etc/network/interfaces` layout:

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

# Bootstrap / template install bridge on the Proxmox uplink NIC.
# Proxmox host IP lives here during bring-up, and temporary build VMs can attach here too.
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

- This example uses the real interface names from the sample host output: `nic0`, `nic1`, and `nic2`.
- Discover the real interface names before editing the file:

```bash
ip -br link
ip -br addr
```

- `ip -br link` shows the interface names and link state in a compact view.
- `ip -br addr` helps identify which interface currently has the Proxmox management IP.
- In this host example, the interface carrying the Proxmox management IP is `nic0`.
- In this host example, `nic0` is bridged into `vmbr0`, and the Proxmox management IP lives on `vmbr0`, not directly on `nic0`.
- In this host example, `nic1` is dedicated to the pfSense WAN bridge `vmbr1`.
- In this host example, `nic2` is dedicated to the pfSense LAN trunk bridge `vmbr2`.
- If you need more hardware detail to tell two similar NICs apart, run:

```bash
networkctl status -a
```

- `networkctl status -a` shows extra details such as link state, driver, and path information that can help map the motherboard port or PCIe NIC port to the Linux interface name.
- Replace `10.10.1.10/24` with the fixed Proxmox uplink IP you want if your site uses a different bootstrap subnet.
- During bootstrap, `vmbr0` is the live Proxmox uplink bridge on `nic0` and can also be used temporarily for installer VMs that need internet access.
- `vmbr1` is the dedicated pfSense WAN bridge.
- `vmbr2` is the pfSense LAN/trunk bridge for internal VM/LXC networking once the final network design is in place.
- `vmbr3` is the separate DMZ or untrusted segment.
- After templates are built, `vmbr0` can remain present but otherwise unused.
- Guests on the internal network should use `bridge = "vmbr2"` with `vlan_id = 20`.
- You do not need host-side bridge names like `vmbr2.20` for guest attachment in this repo.
- Guests on `vmbr3` use a plain DMZ bridge and do not need VLAN tag `66` on the Proxmox side.
- Apply network changes carefully, especially on a remote host.

## 3. Create the Proxmox API token

Run these on the Proxmox host:

```bash
pveum user token add root@pam provider --privsep 0
```

Then update:

- [terraform.tfvars.example](terraform/terraform.tfvars.example)
- your local `terraform/terraform.tfvars`

Create the local file from the example:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

The key values are:

```hcl
pm_api_url          = "https://YOUR-PROXMOX-IP:8006/api2/json"
pm_api_token_id     = "root@pam!provider"
pm_api_token_secret = "PASTE_NEW_SECRET_HERE"
pm_tls_insecure     = true
```

This repo now uses staged Terraform environments:

- `terraform/environments/pfsense` provisions both the pfSense VM and the Linux Mint desktop VM on VMID `150`. This ensures you have a trusted VM to access the pfSense UI immediately after install.
- `terraform/environments/production` owns the remaining workloads and the generated Ansible inventory.
- `terraform/environments/pfsense` uses its own stage-specific build inventory so phase 1 creates only pfSense plus Mint, not the rest of the lab.

If you already have an older single-state checkout under `terraform/terraform.tfstate`,
migrate that state deliberately before adopting the staged roots.

Do not run the staged Terraform applies yet. First finish the remaining host
prep in sections 4 through 10, then use the ordered Terraform flow in sections
11 and 12:

- phase 1: build pfSense and Mint
- stop for the manual pfSense install and first-boot checks
- phase 2: build the remaining VMs and LXCs
- after the production apply, run `./scripts/proxmox-apply-lxc-postcreate.sh`
  on the Proxmox host if the LXC root-only settings still need to be applied

## 4. Prepare Proxmox templates and storage

Before applying Terraform, make sure Proxmox already has:

- the Debian LXC template referenced by `debian_lxc_template`
- a prepared Linux Mint Cinnamon VM template for the Linux Mint desktop VM on VMID `150`
- a prepared VM template for the AI VM clone source
- the required storage targets such as `local-lvm`

Recommended storage names for this repo:

- `vm_storage = "local-lvm"`
- `lxc_storage = "local-lvm"`
- `cloudinit_storage = "local-lvm"`

### LXC template

Debian LXC templates can be downloaded from Proxmox's template repository via
`pveam`. Proxmox documents that templates are available through both the GUI
and `pveam`.

Example on the Proxmox host:

```bash
pveam update
TEMPLATE=$(pveam available | awk '/debian-12-standard/ {print $2; exit}')
pveam download local "$TEMPLATE"
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

If you want the source VM template itself to already contain the `ansible`
account and your SSH key instead of relying only on clone-time cloud-init,
boot the source VM once before converting it into a template and run these
inside the guest:

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

This is optional for the Ubuntu cloud image flow because Terraform already
passes `ansible_user` and `ssh_public_key` to Proxmox cloud-init during clone
creation. It is still useful as a fallback when you want the template itself to
be immediately accessible with the `ansible` account.

The AI VM in this repo is clone-only, so you must provide a valid Ubuntu Server
24.04 LTS template VMID.

Example:

```hcl
vm_template_vmid = 9000
```

### Linux Mint Cinnamon template

For the Linux Mint desktop VM on VMID `150`, prepare a separate Linux Mint Cinnamon desktop template.

Download source:

- Linux Mint Cinnamon from <https://linuxmint.com/download.php>

Recommended flow:

1. On the Proxmox host, download the Linux Mint Cinnamon ISO.
2. On the Proxmox host, create a temporary VM and attach the ISO.
3. In the running Linux Mint installer and then inside the installed Mint VM, complete the OS install and add the packages this repo expects.
4. Back on the Proxmox host, shut the VM down and convert it into a template.

Commands to run on the Proxmox host:

```bash
cd /var/lib/vz/template/iso
wget https://mirror.server.net/linuxmint/iso/stable/22.3/linuxmint-22.3-cinnamon-64bit.iso

qm create 9050 --name linux-mint-cinnamon-template --memory 4096 --cores 4 --net0 virtio,bridge=vmbr0
qm set 9050 --scsihw virtio-scsi-pci --scsi0 local-lvm:64
qm set 9050 --ide2 local:iso/linuxmint-22.3-cinnamon-64bit.iso,media=cdrom
qm set 9050 --boot order=ide2
qm set 9050 --agent enabled=1
qm start 9050
```

Then use the Proxmox console to install Linux Mint normally inside VM `9050`.
If that temporary install network has no DHCP service, set a temporary static
IP inside Mint on the same subnet as the Proxmox host, for example
`10.10.1.50/24` with gateway `10.10.1.1`.

Commands to run inside the running Linux Mint VM after installation:

```bash
sudo apt update
sudo apt install -y openssh-server qemu-guest-agent cloud-init
sudo systemctl enable ssh qemu-guest-agent

# Create the shared automation account used by Terraform and Ansible
sudo useradd -m -s /bin/bash ansible || true
sudo install -d -m 700 -o ansible -g ansible /home/ansible/.ssh
printf '%s\n' 'ssh-ed25519 AAAA...' | sudo tee /home/ansible/.ssh/authorized_keys >/dev/null
sudo chown ansible:ansible /home/ansible/.ssh/authorized_keys
sudo chmod 600 /home/ansible/.ssh/authorized_keys
sudo usermod -aG sudo ansible
printf 'ansible ALL=(ALL) NOPASSWD:ALL\n' | sudo tee /etc/sudoers.d/90-ansible >/dev/null
sudo chmod 440 /etc/sudoers.d/90-ansible

# Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable tailscaled

# RustDesk
wget https://github.com/rustdesk/rustdesk/releases/download/1.4.1/rustdesk-1.4.1-x86_64.deb
sudo apt install -y ./rustdesk-1.4.1-x86_64.deb

sudo cloud-init clean --logs
sudo shutdown now
```

Before converting the Mint VM into a template, confirm the account is present:

```bash
id ansible
sudo -l -U ansible
```

After the VM has powered off, run these on the Proxmox host:

```bash
qm set 9050 --net0 virtio,bridge=vmbr2
qm set 9050 --boot order=scsi0
qm template 9050
```

Why the boot order changes:

- during the install phase, `qm set 9050 --boot order=ide2` tells Proxmox to boot from the attached Linux Mint ISO
- after Mint is installed onto `scsi0`, switch the boot order back to `scsi0` so future boots use the installed disk instead of the installer ISO
- during the template build phase, attaching the VM to `vmbr0` lets it share the Proxmox uplink for package installs
- before converting to a template for this repo, switch the VM back to `vmbr2` so the template matches the intended trusted internal network design

Example Terraform variable:

```hcl
vm050_mint_template_vmid = 9050
```

This template is used in the first staged Terraform apply, so finish the Mint
template before you move on to the pfSense and Mint build steps in sections 11
and 12.

### pfSense install media

`vm100-pfsense` is not a clone template in this repo. Terraform creates the
shell VM with the right VMID, bridges, CPU, memory, and root disk, then you
attach the pfSense ISO and complete the install manually in the Proxmox
console.

Download source:

- pfSense CE ISO:
  <https://shop.netgate.com/a/downloads/-/288d1bf44c98f1a8/10ea4be97213dd88>

This ISO is not fetched automatically by the repo. Add it manually to the
Proxmox ISO storage first. In the working setup here, the ISO filename is:

- `netgate-installer-v1.1.1-RELEASE-amd64.iso`

After Terraform creates VM `100` (pfSense) and VM `150` (Mint), use the ISO
only for the initial pfSense install. The Mint VM can be used to access the
pfSense UI for setup and verification.

```bash
# 1. Attach the installer ISO as the virtual CD-ROM.
qm set 100 --ide2 local:iso/netgate-installer-v1.1.1-RELEASE-amd64.iso,media=cdrom

# 2. Tell Proxmox to boot from the CD-ROM for the first startup.
qm set 100 --boot order=ide2

# 3. Start the VM and complete the install from the Proxmox console.
qm start 100
```

Then finish the pfSense install in the Proxmox console for VM `100`.

For this pfSense VM, use `UFS` during the pfSense installer unless you have a
specific reason to choose guest-side `ZFS`. The intended storage layering in
this repo is a normal pfSense VM disk inside the guest, with Proxmox handling
the host-side storage concerns underneath it.

If the pfSense installer reports `missing or size mismatch`, the simplest fix
is usually to recreate the pfSense VM disk cleanly on the Proxmox host and
retry the install. Check the current disk name first:

```bash
qm config 100
qm stop 100
qm unlink 100 --idlist scsi0
qm set 100 --scsi0 local-lvm:32
qm set 100 --boot order=ide2
qm start 100
```

Then retry the install, choose the fresh target disk, use the whole disk, and
select `UFS`.

After the install completes, pfSense has written itself to the VM disk, which
in the current build is `scsi0`, and the first installed boot succeeds, detach
the ISO and restore normal boot order:

```bash
# Confirm the installed disk name if needed.
qm config 100

# 4. Switch normal boot back to the VM disk.
qm set 100 --boot order=scsi0

# 5. Remove the virtual CD-ROM after install.
qm set 100 --delete ide2
```

At that point continue with:

- interface assignment
- WAN, LAN, and DMZ checks
- the manual pfSense GUI prerequisites in [README-pfsense.md](README-pfsense.md)
- the Ansible pfSense playbook later in this guide

That pfSense walkthrough is intentionally here as reference for the manual
install step in phase 1. It is not the next step in the checklist yet.

From here, keep following the bootstrap guide in order:

- continue with sections 5 through 9 to finish the remaining local Ansible,
  storage, host, and Terraform-variable preparation
- then run section 10 and section 11 for the staged Terraform applies
- in section 11, phase 1 builds pfSense and Mint, then you return to the
  manual pfSense install steps above
- after pfSense is installed and validated, continue with section 11 phase 2
  to build the remaining Terraform-managed VMs and LXCs
- once the production guests exist, use section 12 if you want GPU passthrough
  ready for VM `210`
- only after that do you continue to the Ansible verification and deployment
  steps in sections 13 onward

Choose your path before continuing:

- guided path: run `./scripts/bootstrap-from-proxmox.sh` after you finish
  sections 5 through 9; the script then performs the staged Terraform flow and
  pause points for you
- manual path: keep following the README sections directly, starting with
  section 5 now and then sections 10 through 15 later

Do not wait until after the manual pfSense install to decide whether to use the
guided script. The script is intended to be started before the staged Terraform
applies, not after those manual checkpoints are already complete.

If you want the host storage prepared by Ansible, run the dedicated Proxmox host
storage playbook before Terraform:

- [README-storage.md](README-storage.md)
- [proxmox-storage.yml](ansible/playbooks/proxmox-storage.yml)

Treat [README-storage.md](README-storage.md) as the
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

The helper scripts in [`scripts/`](scripts/) will use:

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

If a checkout ever loses executable bits on the helper scripts, restore them
from the repo root with:

```bash
chmod +x scripts/*.sh
```

This installs the collections declared in:

- [requirements.yml](ansible/requirements.yml)

## 7. Bootstrap Proxmox host storage if required

If this is the first build and you want Ansible to prepare the host NVMe,
appdata ZFS mirror, and initial MergerFS media disk, update:

- [proxmox.yml](ansible/inventories/production/group_vars/proxmox.yml)

Then run:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-storage.yml
```

At this stage, `ansible/inventories/production/hosts.ini` is still the seed
inventory checked into the repo, so the Proxmox host entry there must match the
real bootstrap/uplink IP on `nic0`. For the current layout that should be:

- `proxmox-host ansible_host=10.10.1.10 ansible_user=root`

Before you run that playbook, replace the placeholder `/dev/disk/by-id/...`
values in:

- [proxmox.yml](ansible/inventories/production/group_vars/proxmox.yml)

That storage bootstrap also creates the shared host directories used by the
rest of the lab:

- `/mnt/media_pool/books`
- `/mnt/media_pool/music`
- `/mnt/media_pool/movies`
- `/mnt/media_pool/tv`
- `/mnt/media_pool/torrents`
- `/mnt/media_pool/torrents/books`
- `/mnt/media_pool/torrents/music`
- `/mnt/media_pool/torrents/movies`
- `/mnt/media_pool/torrents/tv`
- `/mnt/media_pool/torrents/incomplete`
- `/mnt/appdata/docker_volumes`
- `/mnt/appdata/configs`

After the initial format-and-create run, set:

```yaml
proxmox_storage_allow_destructive_create: false
```

## 8. Add Tailscale to the Proxmox host if required

If you want secure remote access to the Proxmox host over Tailscale, run the
dedicated Proxmox host playbook:

- [proxmox-host.yml](ansible/playbooks/proxmox-host.yml)

This playbook installs Tailscale on the Proxmox host and brings it online using
the vaulted `TS_AUTHKEY` already stored in:

- [stack.env.vault](ansible/files/compose/lxc240-docker-external/tailscale-peer-relay/stack.env.vault)

Run:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-host.yml
```

That same pre-Terraform seed inventory should point `proxmox-host` at the real
bootstrap/uplink IP on `nic0`.

This gives you Tailscale access to the Proxmox host itself, including the
management interface on `nic0`.

## 9. Configure Terraform variables

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
- `resource_profile`
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

Recommended profile choices:

- minimal VM/LXC build: `resource_profile = "balanced_32gb"`
- full build on the upgraded host: `resource_profile = "balanced_128gb"`

To obtain `ssh_public_key` on the machine where you run Terraform:

```bash
cat ~/.ssh/id_ed25519.pub
```

If you do not already have an Ed25519 key, create one with:

```bash
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_ed25519
```

Then copy the full public key line into `terraform/terraform.tfvars`:

```hcl
ssh_public_key = "ssh-ed25519 AAAA..."
```

## Current guest IP layout

These are UK defaults from `ansible/inventories/production/site_config.yml`:

- Proxmox host uplink IP: `10.10.1.10/24` on `nic0` via `vmbr0`
- `vm100_pfsense`: `10.10.1.110` on `vmbr0`, with additional pfSense-side interfaces on `vmbr1`, `vmbr2`, and `vmbr3`
- Linux Mint desktop VM (`vm050_mint`, VMID `150`): `10.10.10.50` on `vmbr2` with VLAN tag `10`
- `vm210_ai_gpu`: `10.10.20.210` on `vmbr2` with VLAN tag `20`
- `lxc066_docker_arr`: `10.10.66.66` on `vmbr3`
- `lxc200_docker_services`: `10.10.20.200` on `vmbr2` with VLAN tag `20`
- `lxc220_docker_apps`: `10.10.20.220` on `vmbr2` with VLAN tag `20`
- `lxc230_docker_media`: `10.10.20.230` on `vmbr2` with VLAN tag `20`
- `lxc240_docker_external`: `10.10.66.240` on `vmbr3`
- `lxc250_infra`: `10.10.20.250` on `vmbr2` with VLAN tag `20`

## Network intent

- `vmbr0` is the temporary bootstrap/install bridge on the Proxmox uplink.
- `vmbr1` is the pfSense WAN bridge.
- `vmbr2` is the trusted internal trunk.
- The current workstation workload uses VLAN `10` on the `10.10.10.0/24` segment.
- The current server workloads use VLAN `20` on the `10.10.20.0/24` segment.
- VLAN `99` remains the internal management subnet on the trusted LAN side behind pfSense.
- `vmbr3` is the DMZ-style network for isolated or public-facing workloads on the `10.10.66.0/24` segment.
- `lxc066_docker_arr` stays on `vmbr3` and should not have broad access back into the trusted internal network.
- `lxc240_docker_external` stays on `vmbr3` because it serves public-facing workloads.
- `lxc250_infra` stays on `vmbr2` so the reverse proxy can reach trusted internal services directly.
- pfSense needs separate WAN, LAN/trunk, and DMZ interfaces for this design.
- External exposure and NAT are expected to be handled in pfSense, not Terraform.

## 10. Initialize and validate Terraform

Use a two-pass Terraform flow for the full stack.

Phase 1 creates pfSense plus the Linux Mint access VM so you can finish the
router/firewall install and bring the intended networks online before the rest
of the guests depend on them.

Phase 2 creates the remaining VMs and LXCs after pfSense is installed and the
bridge/network design is behaving the way you want.

If you are following the manual path, start with:

```bash
./scripts/terraform-init.sh pfsense
terraform -chdir=terraform/environments/pfsense validate
./scripts/terraform-plan.sh pfsense
./scripts/terraform-apply.sh pfsense
```

Review the plan before applying. The pfSense-stage apply creates both the
pfSense VM and the Linux Mint desktop VM used to access the pfSense UI from
inside the trusted network.

## 11. Apply Terraform In Two Passes

This section describes the manual path. If you already ran
`./scripts/bootstrap-from-proxmox.sh`, the script performs these same staged
Terraform applies and pause points for you.

### Phase 1: Build pfSense and Mint first

Run:

```bash
./scripts/terraform-apply.sh pfsense
```

Then stop and do the manual pfSense work:

- attach `local:iso/netgate-installer-v1.1.1-RELEASE-amd64.iso` to VM `100`
- set boot order to `ide2` and boot from the ISO for the initial install
- install pfSense in the Proxmox console
- after the first installed boot succeeds, set boot order back to `scsi0`
- remove `ide2` so the VM no longer boots from the ISO
- complete the manual steps in [README-pfsense.md](README-pfsense.md)
- make sure the bridges and pfSense-controlled networks are in the state you want

### Phase 2: Build the remaining stack

After pfSense is installed and the network layout is ready, run:

```bash
./scripts/terraform-init.sh production
terraform -chdir=terraform/environments/production validate
./scripts/terraform-plan.sh production
./scripts/terraform-apply.sh production
```

Terraform will:

- create the declared Proxmox VMs and LXCs
- render the Ansible inventory file used by the playbooks

If Terraform creates the LXCs successfully, apply the Proxmox root-only
post-create settings on the host:

```bash
./scripts/proxmox-apply-lxc-postcreate.sh
```

This second step applies:

- `nesting=1,keyctl=1`
- bind mounts for `/mnt/appdata`
- bind mounts for `/mnt/media_pool`

## 12. Prepare GPU passthrough on Proxmox if required

Do this after the `production` Terraform apply has created VM `210`, and before
you expect the AI VM to use the GPU.

This is a Proxmox host preparation step, not a guest configuration step.
Terraform can create the AI VM without the GPU attached, but passthrough itself
depends on the host being configured first.

On the Proxmox host:

1. Enable IOMMU in GRUB.
2. Load the VFIO modules.
3. Bind the RTX 3060 and its audio function to `vfio-pci`.
4. Reboot the host.
5. Discover the GPU PCI address with:

```bash
lspci -nn | grep -iE 'vga|3d|audio'
```

Typical output will look something like:

```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ...
01:00.1 Audio device [0403]: NVIDIA Corporation ...
```

Use the GPU function address, not the audio function. In the example above:

- GPU address: `01:00.0`
- GPU audio address: `01:00.1`

For this repo, record the GPU function in full Proxmox PCI form by adding the
`0000:` domain prefix and dropping the final `.0` function suffix:

- `01:00.0` becomes `0000:01:00`

If VM `210` exists after the `production` Terraform apply, you can confirm what
Proxmox expects for an attached PCI device with:

```bash
qm config 210 | grep -i hostpci
```

Then update your local `terraform/terraform.tfvars`:

```hcl
vm210_gpu_pci_address = "0000:02:00"
```

Important:

- Leave `vm210_gpu_pci_address` blank until you know the real PCI address.
- Run `lspci -nn` on the Proxmox host itself, not inside a guest.
- Use the NVIDIA VGA or 3D controller address, not the NVIDIA audio function.
- If `lspci` shows `01:00.0`, set `vm210_gpu_pci_address = "0000:01:00"`.
- VM `210` and the other production guests are created by section 11 phase 2,
  not by the initial pfSense and Mint stage.
- The exact Terraform PCI device block depends on the installed `bpg/proxmox`
  provider version and the final host hardware layout.
- This repo intentionally does not guess that block before the host exists.
- When the host is ready, update the `vm210-ai-gpu` module to attach the PCI
  device at that recorded address.

## 13. Verify Ansible can see the hosts

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

If the Proxmox host itself is still only reachable from the separate bootstrap
or uplink network, this check can fail even though the guests were created
correctly. In that case, run the Ansible control steps from inside the trusted
network instead, typically from the Linux Mint VM on VMID `150` first and later
from `lxc250_infra` once it is configured.

### 13.1 Prepare Linux Mint as the first internal control node

The Proxmox host can publish the helper scripts into shared appdata:

```bash
./scripts/publish-control-node-bootstrap.sh
```

Inside the Linux Mint VM, use the shared helper path:

```bash
bash /mnt/appdata/homelab-control/bin/fix-mint-apt-repos.sh
bash /mnt/appdata/homelab-control/bin/bootstrap-control-node.sh
```

Use the Mint APT repair helper if `apt update` fails with stale Ubuntu release
entries such as `zena`, `zena-security`, `zena-updates`, or
`zena-backports`. The helper now:

- ensures the shared `virtiofs` mounts exist and persist across reboot
- repairs both `.list` and `.sources` APT definitions
- rewrites stale Ubuntu suites to `noble`, `noble-security`,
  `noble-updates`, and `noble-backports`
- logs full diagnostics to `/tmp/fix-mint-apt-repos.log`

After those helpers succeed, continue from inside Mint:

```bash
cd /mnt/appdata/homelab-control/HomeLab
./scripts/ansible-ping.sh
```

That same shared appdata location can later be reused by `lxc250_infra` as the
long-term Ansible and Semaphore control point.

## 14. First Login For LXCs

The Terraform LXC modules currently create the container root account with the
default password `change-me-now` and also inject your SSH public key.

Change the root password on each LXC after first access from the Proxmox host:

```bash
pct enter <CTID>
passwd
```

Example:

```bash
pct enter 200
passwd
```

Current LXC IDs in this repo:

- `166`
- `200`
- `220`
- `230`
- `240`
- `250`

To rotate them all in one pass with Ansible:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/lxc-root-password.yml
```

The example input file is:

- [lxc_root_passwords.yml.example](/root/HomeLab/ansible/inventories/production/group_vars/lxc_root_passwords.yml.example)

The real vaulted file used by the playbook is:

- [lxc_root_passwords.vault.yml](/root/HomeLab/ansible/inventories/production/group_vars/lxc_root_passwords.vault.yml)

## 15. Run the full deployment

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

## 16. Apply pfSense configuration

After Terraform has built the lab and the Linux hosts have been configured, run
the dedicated pfSense playbook:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/pfsense.yml
```

Before running it, complete the manual pfSense GUI prerequisites in:

- [README-pfsense.md](README-pfsense.md)

## 17. Pull the initial Ollama models

After the AI VM stack is up, log into the AI VM and run these commands in the
AI VM terminal to load the initial Ollama models:

```bash
docker exec -it ollama ollama pull qwen3:8b
docker exec -it ollama ollama pull qwen3:4b
docker exec -it ollama ollama pull qwen2.5-coder:7b
docker exec -it ollama ollama pull qwen2.5vl:7b
docker exec -it ollama ollama pull qwen3-vl:4b
```

Recommended use:

- Chat: `qwen3:8b`
- Coding: `qwen2.5-coder:7b`
- OCR, PDFs, and screenshots: `qwen2.5vl:7b`
- Home Assistant intent and tools: `phi4-mini` later, or `qwen3:4b` now
- Frigate image event summaries: `qwen2.5vl:7b` or `qwen3-vl:4b`

If you later add a model that is not already in Ollama, pull it the same way:

```bash
docker exec -it ollama ollama pull MODEL_NAME
```

These models then become available through the Open WebUI API layer.

Frigate storage layout in this repo is intended to be:

- `/tmp/cache` -> `tmpfs` in RAM
- `/media/frigate/recordings` -> fast persistent storage under `/mnt/ai_cache/frigate`
- `/media/frigate/exports` -> persistent storage under `/mnt/ai_cache/frigate`
- `/dev/shm` -> left as container shared memory, sized with `shm_size`

## 18. Configure the Continue API front door

If you want one consistent API front door and plan to add more providers later,
point Continue at Open WebUI instead of talking directly to Ollama.

Start from:

- [config.yaml.example](continue/config.yaml.example)

This file is a local client-side example for Continue. It is not deployed by
Terraform, Ansible, or Docker Compose.

Example `config.yaml`:

```yaml
name: Homelab Continue
version: 0.0.1
schema: v1

models:
  - name: qwen3chat8b-webui
    provider: openai
    model: qwen3:8b
    apiBase: http://10.10.20.210:3000/api
    apiKey: your-open-webui-api-key

  - name: qwen25coder7b-webui
    provider: openai
    model: qwen2.5-coder:7b
    apiBase: http://10.10.20.210:3000/api
    apiKey: your-open-webui-api-key

  - name: qwen25vl7b-webui
    provider: openai
    model: qwen2.5vl:7b
    apiBase: http://10.10.20.210:3000/api
    apiKey: your-open-webui-api-key

  - name: qwen3mini4b-webui
    provider: openai
    model: qwen3:4b
    apiBase: http://10.10.20.210:3000/api
    apiKey: your-open-webui-api-key

  - name: qwen3vl4b-webui
    provider: openai
    model: qwen3-vl:4b
    apiBase: http://10.10.20.210:3000/api
    apiKey: your-open-webui-api-key

context:
  - provider: code
  - provider: docs
  - provider: diff
  - provider: terminal
```

Notes:

- replace `10.10.20.210` with the real IP or DNS name for your AI VM
- France builds would use `10.20.20.210` with the default site rules
- create and use a real Open WebUI API key after logging into Open WebUI
- Open WebUI will expose models that you have already pulled into Ollama
- Frigate and Home Assistant model selection is configured in those applications, not in these Docker Compose files
- this keeps Continue pointed at one OpenAI-compatible endpoint even if you add
  more local or remote providers later

## 19. Add encrypted stack environment files

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

## 20. Information you may still need to fill in manually

Depending on the environment, you may still need to provide:

- public DNS names
- TLS certificates for the reverse proxy
- VPN credentials for Gluetun-based stacks
- app-specific database passwords and API keys
- Home Assistant, Frigate, Immich, OwnCloud, or WordPress application settings
- GPU passthrough configuration on the Proxmox side for the AI VM
- pfSense interface assignment and final WAN/LAN setup

## Related guides

- [README.md](README.md)
- [README-pfsense.md](README-pfsense.md)
- [README-add-docker-component.md](README-add-docker-component.md)
- [README.md](ansible/README.md)
