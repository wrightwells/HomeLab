# pfSense Guide

This guide covers three things:

- the remaining manual pfSense prerequisites
- what has already been added to Ansible for pfSense
- a reusable prompt/template for future pfSense playbook changes

Use this guide alongside [README-bootstrap.md](/home/ww/HomeLab/HomeLab/README-bootstrap.md).

## Manual Prerequisites

Complete these in the pfSense GUI before running the Ansible pfSense playbook.

### 1. Install `pfBlockerNG-devel`

In the pfSense GUI:

```text
System -> Package Manager -> Available Packages
```

Install:

- `pfBlockerNG-devel`

Why it stays manual:

- it creates package-managed aliases and internal config sections
- those generated objects are not good first-pass Ansible targets

### 2. Install `Tailscale`

In the pfSense GUI:

```text
System -> Package Manager -> Available Packages
```

Install:

- `Tailscale`

Why it stays manual:

- node registration and auth are package-specific
- interface/package lifecycle is safer to complete in the GUI first

### 3. Manually configure the `PIA_VPN` OpenVPN client

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
Update the pfSense Ansible automation in /home/ww/HomeLab/HomeLab.

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

- Current pfSense inventory IP: `10.10.99.1`
- pfSense is intentionally separate from Linux-host roles
- package-specific edge cases remain manual in the first pass
