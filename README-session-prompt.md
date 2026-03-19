# Session Prompt Template

Use this file as a reusable prompt or handoff document for future coding
sessions about this homelab. It is designed to work in this repo and also as a
starting point for a future repo where the hardware, network, or service
placement changes.

## How To Use This File

Copy the template block below into a future coding session and replace the
placeholders or current snapshot values as needed.

The goal is to give a future coding agent enough context to:

- understand the hardware and storage layout
- understand why VMs and LXCs are placed where they are
- understand which Docker services live on which host
- move services between hosts safely in a future rebuild
- know which files in the repo are the source of truth

## Prompt Template

```text
You are helping maintain or rebuild a Proxmox-based homelab.

Use the repo files as the source of truth, but start from this summary.

Hardware:
- Primary site: [REPLACE_ME]
- Secondary site: [REPLACE_ME]
- Proxmox host model: [REPLACE_ME]
- CPU: [REPLACE_ME]
- RAM now: [REPLACE_ME]
- RAM planned later: [REPLACE_ME]
- GPU: [REPLACE_ME]
- NIC layout: [REPLACE_ME]

Storage design:
- Proxmox OS disk: [REPLACE_ME]
- AI fast storage: [REPLACE_ME]
- Appdata storage: [REPLACE_ME]
- Media storage: [REPLACE_ME]
- Important mount points: [REPLACE_ME]

Network design:
- Proxmox management subnet: [REPLACE_ME]
- Internal trusted subnet/VLAN: [REPLACE_ME]
- DMZ subnet/VLAN: [REPLACE_ME]
- WAN/LAN/DMZ bridge mapping: [REPLACE_ME]
- pfSense role in the design: [REPLACE_ME]

Terraform design:
- Provider: bpg/proxmox
- VMs should be clone-based or otherwise note exceptions
- Resource sizing is profile-driven if available
- Terraform creates guests, not Proxmox host networking

Ansible design:
- Docker services are deployed from ansible/files/compose
- Writable host bind mounts should be pre-created by Ansible
- stack.env.vault is decrypted by Ansible at deploy time
- pfSense is managed separately from Linux hosts

Placement rules:
- Put public-facing services on [REPLACE_ME]
- Put trusted internal apps on [REPLACE_ME]
- Put media services on [REPLACE_ME]
- Put AI services on [REPLACE_ME]
- Put infra/monitoring on [REPLACE_ME]
- Put download/ARR services on [REPLACE_ME]

Current hosts and intended purpose:
- [REPLACE_ME]

Current Docker services by host:
- [REPLACE_ME]

When changing service placement:
- preserve storage path assumptions
- preserve firewall/DMZ intent
- preserve reverse proxy entry points
- preserve service-to-service dependencies
- update Terraform, Ansible roles, compose bundles, inventory, docs, and service catalog together

Important repo files:
- README-bootstrap.md
- README-storage.md
- README-sizing.md
- README-services.md
- terraform/main.tf
- ansible/inventories/production/hosts.ini
- ansible/inventories/production/group_vars/all.yml
- ansible/playbooks/site.yml
- ansible/playbooks/pfsense.yml

Task for this session:
- [REPLACE_ME]
```

## Current Snapshot

### Hardware

- Primary Proxmox host model: `HP Z420`
- CPU plan: `12 cores / 24 threads`
- RAM plan:
  - `32 GB` now
  - `64 GB` later
  - `128 GB` later
- GPU plan: `MSI GeForce RTX 3060 Ventus 2X 12GB`

### Storage

- Proxmox OS disk: `500 GB SATA SSD`, `ext4`
- AI fast storage: host NVMe, `ext4`
- Appdata storage: `ZFS mirror`
- Media storage: `xfs` member disks combined with `mergerfs`

Important host mount points:

- `/mnt/ai_models`
- `/mnt/ai_cache`
- `/mnt/appdata`
- `/mnt/media_pool`

Shared host directories created during storage bootstrap include:

- `/mnt/appdata/docker_volumes`
- `/mnt/appdata/configs`
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

### Network

- Proxmox management IP: `10.10.99.10/24`
- Proxmox management NIC: `eno1`
- Proxmox management gateway: `10.10.99.1`
- pfSense WAN bridge: `vmbr0`
- Internal trusted bridge: `vmbr1`
- Internal trusted VLAN: `20`
- Internal trusted subnet: `10.10.20.0/24`
- DMZ-style bridge: `vmbr2`
- DMZ subnet: `10.10.66.0/24`

### Terraform / Ansible Design Rules

- Provider source: `bpg/proxmox`
- AI VM is clone-only from an Ubuntu 24.04 cloud image template
- LXCs use the Debian 12 standard LXC template
- Terraform does not configure Proxmox host networking
- Terraform sizing and start behavior are profile-driven
- Ansible deploys Docker compose bundles from `ansible/files/compose`
- Ansible pre-creates important writable bind-mount directories
- pfSense lives in its own Ansible inventory group and playbook

### Current Host Purposes

| Host | IP | Purpose |
| --- | --- | --- |
| `vm210-ai-gpu` | `10.10.20.210` | AI services, Frigate, Home Assistant, automation, coding tools |
| `lxc066-docker-arr` | `10.10.66.66` | ARR stack, downloads, request tools |
| `lxc200-docker-services` | `10.10.20.200` | data and sync services |
| `lxc220-docker-apps` | `10.10.20.220` | general-purpose apps |
| `lxc230-docker-media` | `10.10.20.230` | media servers |
| `lxc240-docker-external` | `10.10.66.240` | public-facing and DMZ services |
| `lxc250-infra` | `10.10.20.250` | infra, monitoring, MQTT, Homebridge |

### Placement Intent

- `vm210-ai-gpu`:
  - AI and GPU workloads
  - Frigate
  - Home Assistant
  - local automation and coding support
- `lxc066-docker-arr`:
  - download and media acquisition stack
  - request and file-browser helpers
  - DMZ-style isolation
- `lxc200-docker-services`:
  - sync, file, and photo/data services
- `lxc220-docker-apps`:
  - user-facing internal apps
- `lxc230-docker-media`:
  - Jellyfin, Plex, media-serving workloads
- `lxc240-docker-external`:
  - reverse proxy and public or semi-public services
  - DMZ placement matters here
- `lxc250-infra`:
  - MQTT
  - Homebridge
  - monitoring and uptime tooling

### Docker Bundles By Host

List bundles by:

- bundle name
- compose service names
- container names if they differ
- image references, including pinned or tagged versions where present

#### `vm210-ai-gpu`

- bundle `ai-models`
  - compose services:
    - `ollama` -> container `ollama` -> image `ollama/ollama:latest`
    - `open-webui` -> container `open-webui` -> image `ghcr.io/open-webui/open-webui:main`
- bundle `frigate`
  - compose services:
    - `frigate` -> container `frigate` -> image `ghcr.io/blakeblackshear/frigate:stable`
- bundle `home-assistant`
  - compose services:
    - `homeassistant` -> container `homeassistant` -> image `ghcr.io/home-assistant/home-assistant:stable`
- bundle `n8n`
  - compose services:
    - `n8n` -> container `n8n` -> image `docker.n8n.io/n8nio/n8n:latest`
- bundle `openvscode-server`
  - compose services:
    - `openvscode-server` -> container `openvscode-server` -> image `lscr.io/linuxserver/openvscode-server:latest`

#### `lxc066-docker-arr`

- bundle `arr-stack`
  - compose services:
    - `gluetun` -> container `gluetun` -> image `qmcgaw/gluetun`
    - `qbittorrent` -> container `qbittorrent` -> image `lscr.io/linuxserver/qbittorrent`
    - `prowlarr` -> container `prowlarr` -> image `lscr.io/linuxserver/prowlarr:latest`
    - `sonarr` -> container `sonarr` -> image `lscr.io/linuxserver/sonarr:latest`
    - `radarr` -> container `radarr` -> image `lscr.io/linuxserver/radarr:latest`
    - `lidarr` -> container `lidarr` -> image `lscr.io/linuxserver/lidarr:latest`
    - `bazarr` -> container `bazarr` -> image `lscr.io/linuxserver/bazarr:latest`
    - `readarr` -> container `readarr` -> image `lscr.io/linuxserver/readarr:develop`
- bundle `filebrowser`
  - compose services:
    - `filebrowser` -> container `filebrowser` -> image `filebrowser/filebrowser:latest`
- bundle `jellyseerr`
  - compose services:
    - `jellyseerr` -> container `jellyseerr` -> image `fallenbagel/jellyseerr:latest`
- bundle `aurral`
  - compose services:
    - `aurral` -> container `aurral` -> image `ghcr.io/lklynet/aurral:latest`

#### `lxc200-docker-services`

- bundle `immich`
  - compose services:
    - `immich-server` -> container `immich_server` -> image `ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}`
    - `immich-machine-learning` -> container `immich_machine_learning` -> image `ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}`
    - `redis` -> container `immich_redis` -> image `docker.io/valkey/valkey:9@sha256:fb8d272e529ea567b9bf1302245796f21a2672b8368ca3fcb938ac334e613c8f`
    - `database` -> container `immich_postgres` -> image `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23`
- bundle `owncloud`
  - compose services:
    - `owncloud` -> container `owncloud` -> image `owncloud/server:${OWNCLOUD_VERSION}`
    - `db` -> container `owncloud_db` -> image `mariadb:10.11`
    - `redis` -> container `owncloud_redis` -> image `redis:7-alpine`
    - `cron` -> container auto-generated -> image `owncloud/server:${OWNCLOUD_VERSION}`
- bundle `syncthing`
  - compose services:
    - `syncthing` -> container `syncthing` -> image `lscr.io/linuxserver/syncthing:latest`

#### `lxc220-docker-apps`

- bundle `blinko`
  - compose services:
    - `blinko-db` -> container `blinko-db` -> image `postgres:16`
    - `blinko` -> container `blinko` -> image `blinkospace/blinko:latest`
- bundle `calibre-web`
  - compose services:
    - `calibre-web` -> container `calibre-web` -> image `lscr.io/linuxserver/calibre-web:latest`
- bundle `calibre`
  - compose services:
    - `calibre` -> container `calibre` -> image `lscr.io/linuxserver/calibre:latest`
- bundle `eurgo`
  - compose services:
    - `erugo` -> container `erugo` -> image `wardy784/erugo:latest`
- bundle `finance`
  - compose services:
    - `app` -> container `firefly_iii_core` -> image `fireflyiii/core:latest`
    - `db` -> container `firefly_iii_db` -> image `mariadb:lts`
    - `cron` -> container `firefly_iii_cron` -> image `alpine`
- bundle `grafana`
  - compose services:
    - `grafana` -> container `grafana` -> image `grafana/grafana`
- bundle `grist`
  - compose services:
    - `grist` -> container `grist` -> image `gristlabs/grist:latest`
- bundle `homarr`
  - compose services:
    - `homarr` -> container `homarr` -> image `ghcr.io/homarr-labs/homarr:latest`
- bundle `influxdb`
  - compose services:
    - `influxdb` -> container `influxdb` -> image `influxdb:1.8`
- bundle `node-red`
  - compose services:
    - `node-red` -> container `node-red` -> image `nodered/node-red:latest`
- bundle `pairdrop`
  - compose services:
    - `pairdrop` -> container `pairdrop` -> image `ghcr.io/schlagmichdoch/pairdrop:latest`
- bundle `semaphore`
  - compose services:
    - `semaphore` -> container `ansible-semaphore` -> image `semaphoreui/semaphore:latest`
- bundle `teslamate`
  - compose services:
    - `teslamate` -> container `teslamate` -> image `teslamate/teslamate:1.28.2`
    - `postgres` -> container `teslamate_postgres` -> image `postgres:14`

#### `lxc230-docker-media`

- bundle `jellyfin`
  - compose services:
    - `jellyfin` -> container `jellyfin` -> image `lscr.io/linuxserver/jellyfin:latest`
- bundle `plex`
  - compose services:
    - `plex` -> container `plex` -> image `lscr.io/linuxserver/plex:latest`
- bundle `jellyswarrm`
  - compose services:
    - `tailscale` -> container `tailscale` -> image `tailscale/tailscale:latest`
    - `jellyswarrm` -> container `jellyswarrm-proxy` -> image `ghcr.io/llukas22/jellyswarrm:latest`

#### `lxc240-docker-external`

- bundle `dnns`
  - compose services:
    - `cloudflare-ddns-all` -> container `cloudflare-ddns-all` -> image `oznu/cloudflare-ddns:latest`
    - `cloudflare-ddns-all-uk` -> container `cloudflare-ddns-all-uk` -> image `oznu/cloudflare-ddns:latest`
    - `cloudflare-ddns-uk` -> container `cloudflare-ddns-uk` -> image `oznu/cloudflare-ddns:latest`
    - `cloudflare-ddns-art` -> container `cloudflare-ddns-art` -> image `oznu/cloudflare-ddns:latest`
- bundle `ghost`
  - compose services:
    - `ghost` -> container `ghost-art` -> image `ghost:5`
- bundle `kutt`
  - compose services:
    - `kutt` -> container auto-generated -> image `kutt/kutt`
    - `db` -> container auto-generated -> image `postgres:14`
- bundle `nginx`
  - compose services:
    - `nginx` -> container `nginx` -> image `nginx:1.28-alpine`
- bundle `rustdesk`
  - compose services:
    - `tailscale` -> container `rustdesk_tailscale` -> image `tailscale/tailscale:latest`
    - `hbbs` -> container `rustdesk_id` -> image `rustdesk/rustdesk-server:latest`
    - `hbbr` -> container `rustdesk_relay` -> image `rustdesk/rustdesk-server:latest`
- bundle `tailscale-peer-relay`
  - compose services:
    - `tailscale-peer-relay` -> container `tailscale-peer-relay` -> image `tailscale/tailscale:latest`
- bundle `walletpage`
  - compose services:
    - `walletpage` -> container `walletpage` -> image `nginx:alpine`
- bundle `wordpress`
  - compose services:
    - `wordpress` -> container `wordpress` -> image `wordpress:6.9.1-php8.2-apache`
    - `db` -> container `wordpress_db` -> image `mariadb:10.11.6`

#### `lxc250-infra`

- bundle `alertmanager`
  - compose services:
    - `alertmanager` -> container `alertmanager` -> image `prom/alertmanager:latest`
- bundle `grafana`
  - compose services:
    - `grafana` -> container `grafana` -> image `grafana/grafana:latest`
- bundle `homebridge`
  - compose services:
    - `homebridge` -> container `homebridge` -> image `homebridge/homebridge:latest`
- bundle `mqtt`
  - compose services:
    - `mosquitto` -> container `mosquitto` -> image `eclipse-mosquitto:latest`
- bundle `prometheus`
  - compose services:
    - `prometheus` -> container `prometheus` -> image `prom/prometheus:latest`
- bundle `uptime-kuma`
  - compose services:
    - `uptime-kuma` -> container `uptime-kuma` -> image `louislam/uptime-kuma:latest`

## When Moving Services Between Hosts

If a future build needs to move containers between hosts, preserve these checks:

### 1. Network and security intent

- Does the service belong on the trusted side or in the DMZ?
- Does it need reverse proxy exposure?
- Does it need inbound WAN or Tailscale-specific access?

### 2. Storage assumptions

- Does it need `/mnt/appdata`, `/mnt/media_pool`, `/mnt/ai_models`, or `/mnt/ai_cache`?
- Does it need fast disk, mirrored disk, or just generic app storage?
- Does it require pre-created writable host paths with `1000:1000` ownership?

### 3. Service dependencies

- Does it depend on MQTT?
- Does it depend on Ollama or Open WebUI?
- Does it depend on shared media paths?
- Does it depend on the reverse proxy?

### 4. Files to update together

- Terraform module placement or host definitions if the host changes
- Ansible role task list for the target host
- compose bundle path under `ansible/files/compose/...`
- `docker_host_paths` declarations for writable mounts
- service catalog in `README-services.md`
- bootstrap or storage docs if the architecture changes

## Repo Files A Future Session Should Read First

- [README-bootstrap.md](README-bootstrap.md)
- [README-storage.md](README-storage.md)
- [README-sizing.md](README-sizing.md)
- [README-services.md](README-services.md)
- [README-pfsense.md](README-pfsense.md)
- [terraform/main.tf](terraform/main.tf)
- [ansible/inventories/production/hosts.ini](ansible/inventories/production/hosts.ini)
- [ansible/inventories/production/group_vars/all.yml](ansible/inventories/production/group_vars/all.yml)
- [ansible/playbooks/site.yml](ansible/playbooks/site.yml)
- [ansible/playbooks/pfsense.yml](ansible/playbooks/pfsense.yml)

## Suggested Future Prompt

```text
Use README-session-prompt.md and the repo files it references as the starting
context for this homelab session.

Before making changes:
- review the current hardware and placement snapshot
- review the service catalog
- review Terraform sizing and networking
- review the relevant Ansible role and compose bundle

Task:
- [describe the change]

Constraints:
- preserve the intended trusted/DMZ split unless explicitly changing it
- preserve storage path conventions unless explicitly changing them
- keep Docker writable host paths managed by Ansible
- update docs if service placement, URLs, or operating flow changes
```
