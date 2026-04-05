# Networking Guide

This document summarizes the current production networking layout for the UK site.
The values here are derived from:

- `ansible/inventories/production/site_config.yml`
- `ansible/inventories/production/group_vars/pfsense_firewall.yml`

## Addressing model

This site currently uses:

- first octet: `10`
- second octet: `10`
- host addressing pattern: `10.10.<vlan>.<host_id>`

## Bridge layout

| Bridge | Purpose | Notes |
| --- | --- | --- |
| `vmbr0` | Bootstrap / template install bridge | Temporary bridge on `nic0` so installer VMs can reach the upstream network during bootstrap; can remain unused in the end state |
| `vmbr1` | pfSense WAN | Dedicated bridge on `nic1` for the pfSense WAN interface |
| `vmbr2` | Trusted internal trunk | Dedicated bridge on `nic2` for the pfSense LAN trunk and internal VLAN-backed workloads |
| `vmbr3` | DMZ-style network | Untrusted bridge used for isolated or public-facing workloads |

## Proxmox bootstrap uplink

The Proxmox host itself uses the dedicated bootstrap/uplink subnet on `nic0`:

- subnet: `10.10.1.0/24`
- Proxmox host IP: `10.10.1.10`
- upstream gateway: `10.10.1.1`
- host-facing bridge during bootstrap: `vmbr0`

That network is separate from the pfSense-managed internal VLANs. In the steady
state, `vmbr0` can be left unused apart from occasional template builds.

## VLAN and subnet layout

| VLAN | Name | Subnet | Gateway IP |
| --- | --- | --- | --- |
| `99` | Management | `10.10.99.0/24` | `10.10.99.1` |
| `10` | Workstations | `10.10.10.0/24` | `10.10.10.1` |
| `20` | Servers | `10.10.20.0/24` | `10.10.20.1` |
| `30` | Media | `10.10.30.0/24` | `10.10.30.1` |
| `40` | IoT | `10.10.40.0/24` | `10.10.40.1` |
| `50` | CCTV | `10.10.50.0/24` | `10.10.50.1` |
| `60` | Guest | `10.10.60.0/24` | `10.10.60.1` |
| `66` | DMZ | `10.10.66.0/24` | `10.10.66.1` |
## Server IPs

| Role | Hostname | Type | Network | Bridge | IP address |
| --- | --- | --- | --- | --- | --- |
| Proxmox host | `pve01` | Physical host | Bootstrap / host uplink | `vmbr0` | `10.10.1.10` |
| pfSense | `pfsense` | VM | Bootstrap / control | `vmbr0` | `10.10.1.110` |
| Mint desktop | `vm050-mint` (VMID `150`) | VM | Workstations | `vmbr2` | `10.10.10.50` |
| AI GPU | `ai-gpu` | VM | Servers | `vmbr2` | `10.10.20.210` |
| Docker ARR | `docker-arr` | LXC | DMZ | `vmbr3` | `10.10.66.66` |
| Docker services | `docker-services` | LXC | Servers | `vmbr2` | `10.10.20.200` |
| Docker apps | `docker-apps` | LXC | Servers | `vmbr2` | `10.10.20.220` |
| Docker media | `docker-media` | LXC | Servers | `vmbr2` | `10.10.20.230` |
| Docker external | `docker-external` | LXC | DMZ | `vmbr3` | `10.10.66.240` |
| Infra | `infra-01` | LXC | Servers | `vmbr2` | `10.10.20.250` |

## Network intent

- `vmbr0` exists so templates and one-off installer VMs can borrow the Proxmox uplink on `nic0` during bootstrap.
- `vmbr1` is reserved for the pfSense WAN on `nic1`.
- `vmbr2` is the trusted internal bridge for the pfSense LAN trunk plus workstation and server VLANs.
- `vmbr3` is reserved for isolated or public-facing services.
- `lxc066_docker_arr` and `lxc240_docker_external` stay on the DMZ-style network.
- `lxc250_infra` remains on the trusted servers network so internal services can reach it directly.
- pfSense owns inter-VLAN routing, firewall policy, and external NAT.
