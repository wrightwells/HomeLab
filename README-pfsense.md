# pfSense Guide

This guide covers three things:

- the remaining manual pfSense prerequisites
- what has already been added to Ansible for pfSense
- a reusable prompt/template for future pfSense playbook changes

Use this guide alongside [README-bootstrap.md](README-bootstrap.md).

## Build The Base pfSense VM

`vm100-pfsense` is currently a Terraform-created shell VM, not a clone
template. Terraform gives you VM `100` with the expected bridges and disk, then
you attach the pfSense ISO and install pfSense manually.

Download source:

- pfSense CE ISO:
  <https://shop.netgate.com/a/downloads/-/288d1bf44c98f1a8/10ea4be97213dd88>

This ISO is not fetched automatically by the repo. Add it manually to the
Proxmox ISO storage first. In the working setup here, the ISO filename is:

- `netgate-installer-v1.1.1-RELEASE-amd64.iso`

After Terraform creates VM `100`, use the ISO only for the initial install
boot:

```bash
# 1. Attach the installer ISO as the virtual CD-ROM.
qm set 100 --ide2 local:iso/netgate-installer-v1.1.1-RELEASE-amd64.iso,media=cdrom

# 2. Tell Proxmox to boot from the CD-ROM for the first startup.
qm set 100 --boot order=ide2

# 3. Start the VM and open the Proxmox console to run the installer.
qm start 100
```

Then complete the pfSense install in the Proxmox console.

For this pfSense VM, choose `UFS` in the installer unless you have a specific
reason to use guest-side `ZFS`. In this repo, pfSense is expected to use a
simple VM disk and let Proxmox handle the storage layer underneath.

If the installer reports `missing or size mismatch`, recreate the pfSense VM
disk cleanly on the Proxmox host and retry. Check the current disk name first:

```bash
qm config 100
qm stop 100
qm unlink 100 --idlist scsi0
qm set 100 --scsi0 local-lvm:32
qm set 100 --boot order=ide2
qm start 100
```

Then rerun the install, select the fresh target disk, use the whole disk, and
choose `UFS`.

After the installer has finished, pfSense has written itself to the VM disk,
which in the current build is `scsi0`, and
the first installed boot succeeds, remove the install media so later boots use
the VM disk instead of the ISO:

```bash
# Confirm the installed disk name if needed.
qm config 100

# 4. Switch normal boot back to the VM disk.
qm set 100 --boot order=scsi0

# 5. Remove the virtual CD-ROM now that install is complete.
qm set 100 --delete ide2
```

## Manual Prerequisites

Complete these in the pfSense GUI before running the Ansible pfSense playbook.

### 1. Set the pfSense hostname and domain

The build config expects these pfSense identity values:

- `pfsense`
- `uk.wrightwells.com`

This comes from:

- [site_config.yml](ansible/inventories/production/site_config.yml)

In the pfSense GUI:

```text
System -> General Setup
```

Set:

- Hostname: `pfsense`
- Domain: `uk.wrightwells.com`

Note:

- UK builds use `uk.wrightwells.com`
- France builds use `fr.wrightwells.com`

### 2. Install `pfBlockerNG-devel`

In the pfSense GUI:

```text
System -> Package Manager -> Available Packages
```

Install:

- `pfBlockerNG-devel`

Why it stays manual:

- it creates package-managed aliases and internal config sections
- those generated objects are not good first-pass Ansible targets

### 3. Install `Tailscale`

In the pfSense GUI:

```text
System -> Package Manager -> Available Packages
```

Install:

- `Tailscale`

Why it stays manual:

- node registration and auth are package-specific
- interface/package lifecycle is safer to complete in the GUI first

### 4. Install `ntopng`

In the pfSense GUI:

```text
System -> Package Manager -> Available Packages
```

Install:

- `ntopng`

Recommended first-pass package configuration:

- enable the package
- select the interfaces you want it to monitor
- confirm it starts correctly before relying on it operationally

Why it stays manual:

- package tuning and traffic-observation choices are package-specific
- the right interfaces and retention settings are easier to verify live first

### 5. Manually configure the WAN `PPPoE` connection

In the pfSense GUI:

```text
Interfaces -> WAN
```

Configure the WAN for your ISP's PPPoE connection, including:

- PPPoE username
- PPPoE password
- any ISP-specific MTU, MSS, VLAN, or service-name requirements

Why it stays manual:

- the currently installed `pfsensible.core` interface module in this repo does
  not expose PPPoE as a supported `ipv4_type`
- PPPoE credentials are sensitive
- WAN connectivity is too critical to make first-pass bring-up depend on
  lower-level or brittle automation

### 6. Manually configure the `PIA_VPN` OpenVPN client

In the pfSense GUI:

```text
VPN -> OpenVPN -> Clients
```

Why it stays manual:

- provider credentials are sensitive
- client-specific routing behavior should be verified live before automation is
  expanded

## What Has Been Added To Ansible

The pfSense automation has already been structured in the repo.

### Inventory

pfSense now lives in its own inventory group, separate from Linux hosts:

- [hosts.ini](ansible/inventories/production/hosts.ini)
- group: `pfsense_firewall`

### Group variables

Policy intent is now expressed as YAML data in:

- [pfsense_firewall.yml](ansible/inventories/production/group_vars/pfsense_firewall.yml)

This file contains:

- interface intent
- VLAN intent
- aliases
- firewall rule groups
- NAT rules
- validation expectations

### Playbook

The dedicated pfSense playbook is:

- [pfsense.yml](ansible/playbooks/pfsense.yml)

Run it with:

```bash
cd ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/pfsense.yml
```

### Role

The dedicated role is:

- [main.yml](ansible/roles/pfsense_firewall/tasks/main.yml)

Supporting tasks:

- [apply.yml](ansible/roles/pfsense_firewall/tasks/apply.yml)
- [validate.yml](ansible/roles/pfsense_firewall/tasks/validate.yml)

### Collection

The implementation uses `pfsensible.core` where supported.

Configured in:

- [requirements.yml](ansible/requirements.yml)
- [ansible.cfg](ansible/ansible.cfg)

Current module usage includes:

- `pfsense_vlan`
- `pfsense_interface`
- `pfsense_alias`
- `pfsense_rule`
- `pfsense_nat_port_forward`

## What The Current pfSense Playbook Manages

The current automation is intended to manage:

- interfaces
- VLANs
- aliases
- firewall rules
- NAT rules

The current validation step checks for:

- gateways
- DHCP markers
- package markers

## Current Operating Model

The intended flow is:

1. Build the Proxmox host and storage.
2. Run Terraform to create the lab guests.
3. Run the Linux Ansible playbooks.
4. Complete the pfSense GUI prerequisites above.
5. Run the dedicated pfSense playbook.

## Prompt Template For Future pfSense Changes

Use this as a prompt template when you want to extend the pfSense automation in
the future:

```text
Update the pfSense Ansible automation in /home/ww/HomeLab.

Constraints:
- Keep pfSense in the dedicated inventory group pfsense_firewall.
- Use YAML data in ansible/inventories/production/group_vars/pfsense_firewall.yml.
- Use pfsensible.core where supported.
- Keep package-specific edge cases manual unless I explicitly ask to automate them.
- Update README-pfsense.md and README-bootstrap.md if the operating flow changes.

Requested change:
- [describe the interface, VLAN, alias, firewall rule, NAT rule, DHCP, or validation change]

Validation:
- Run ansible-playbook --syntax-check for playbooks/pfsense.yml
- Keep the playbook structure readable and data-driven
```

## Notes

- Current pfSense inventory IP: UK default `10.10.1.110`; France builds use `10.20.1.110` from `ansible/inventories/production/site_config.yml`
- pfSense is intentionally separate from Linux-host roles
- package-specific edge cases remain manual in the first pass
