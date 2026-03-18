# Bootstrap Guide

This guide walks through the initial setup of this repo on a host that already
has:

- Proxmox VE installed
- Terraform installed
- Ansible installed

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
- bridge name for VM/LXC networking, for example `vmbr0`
- storage names for:
  - VM disks
  - LXC root filesystems
  - cloud-init disks
- the VMID of the prepared AI VM template clone source
- the Debian LXC template path already present in Proxmox
- your Ansible SSH public key
- your Ansible vault password

## 2. Configure the Proxmox management NIC

Use the onboard NIC as the fixed management interface.

Example `/etc/network/interfaces` layout:

```text
auto lo
iface lo inet loopback

iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
    address 10.10.1.10/24
    gateway 10.10.1.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0

iface eno2 inet manual
iface eno3 inet manual
```

Notes:

- Replace `eno1` with the onboard NIC name on your host.
- Replace `10.10.1.10/24` with the fixed Proxmox management IP you want.
- `eno2` and `eno3` are placeholders for the additional NICs you may later pass
  through or dedicate for pfSense WAN/LAN use.
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

The AI VM in this repo is clone-only, so you must provide a valid template VMID.

Example:

```hcl
vm210_clone_vmid = 9000
```

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

## 7. Configure Terraform variables

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
- `vm210_clone_vmid`
- `vm_storage`
- `lxc_storage`
- `cloudinit_storage`
- `vm_bridge`
- `vm_vlan`
- `debian_lxc_template`
- `ansible_user`
- `ssh_public_key`

## 8. Initialize and validate Terraform

Run:

```bash
./scripts/terraform-init.sh
terraform -chdir=terraform validate
./scripts/terraform-plan.sh
```

Review the plan before applying.

## 9. Apply Terraform

Run:

```bash
./scripts/terraform-apply.sh
```

Terraform will:

- create the declared Proxmox VMs and LXCs
- render the Ansible inventory file used by the playbooks

## 10. Verify Ansible can see the hosts

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

## 11. Run the full deployment

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

## 12. Add encrypted stack environment files

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

## 13. Information you may still need to fill in manually

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
