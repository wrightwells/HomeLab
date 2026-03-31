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
| `vmbr0` | Management / pfSense WAN-side connectivity | Proxmox host management and pfSense management-side attachment |
| `vmbr1` | Trusted internal trunk | Carries internal VLAN-backed workloads such as workstations and servers |
| `vmbr2` | DMZ-style network | Used for isolated or public-facing workloads |

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
| `1` | pfSense LAN transit | `10.10.1.0/24` | `10.10.1.1` |

## Server IPs

| Role | Hostname | Type | Network | Bridge | IP address |
| --- | --- | --- | --- | --- | --- |
| Proxmox host | `pve01` | Physical host | Management | `vmbr0` | `10.10.99.10` |
| pfSense | `pfsense` | VM | Management | `vmbr0` | `10.10.99.1` |
| Mint desktop | `vm050-mint` | VM | Workstations | `vmbr1` | `10.10.10.50` |
| AI GPU | `ai-gpu` | VM | Servers | `vmbr1` | `10.10.20.210` |
| Docker ARR | `docker-arr` | LXC | DMZ | `vmbr2` | `10.10.66.66` |
| Docker services | `docker-services` | LXC | Servers | `vmbr1` | `10.10.20.200` |
| Docker apps | `docker-apps` | LXC | Servers | `vmbr1` | `10.10.20.220` |
| Docker media | `docker-media` | LXC | Servers | `vmbr1` | `10.10.20.230` |
| Docker external | `docker-external` | LXC | DMZ | `vmbr2` | `10.10.66.240` |
| Infra | `infra-01` | LXC | Servers | `vmbr1` | `10.10.20.250` |

## Network intent

- `vmbr1` is the trusted internal bridge for workstation and server VLANs.
- `vmbr2` is reserved for isolated or public-facing services.
- `lxc066_docker_arr` and `lxc240_docker_external` stay on the DMZ-style network.
- `lxc250_infra` remains on the trusted servers network so internal services can reach it directly.
- pfSense owns inter-VLAN routing, firewall policy, and external NAT.
