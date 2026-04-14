# Service Catalog

This file lists the currently defined services in the repo, the host they run
on, the expected IP and port, and what each service is for.

Notes:

- URLs below reflect the default UK site configuration in `ansible/inventories/production/site_config.yml`.
- France builds use the same host IDs and VLAN layout but switch to the `10.20.x.x` range.
- Some services are internal-only helpers such as databases, VPN sidecars, or
  relays and do not have a direct browser UI.
- A few host-networked services rely on the application's default port because
  no explicit port mapping is set in the compose file.

## Host IP Map

| Host | IP | Purpose |
| --- | --- | --- |
| `vm050-mint` (VMID `150`) | `10.10.10.50` | Linux Mint Cinnamon desktop VM with Tailscale and HomeLab tools |
| `vm210-ai-gpu` | `10.10.20.210` | AI services, Frigate, Home Assistant, coding tools |
| `vm300-openclaw` (VMID `300`) | `10.10.66.70` | OpenClaw Telegram bot gateway, Open WebUI |
| `lxc066-docker-arr` | `10.10.66.66` | ARR stack, downloads, media request tools |
| `lxc200-docker-services` | `10.10.20.200` | Core data services and sync tools |
| `lxc220-docker-apps` | `10.10.20.220` | General-purpose apps |
| `lxc230-docker-media` | `10.10.20.230` | Media servers |
| `lxc240-docker-external` | `10.10.66.240` | Public-facing and DMZ services |
| `lxc250-infra` | `10.10.20.250` | Infra, monitoring, MQTT, Docker management, Homebridge |

## Services

| Service | Host | IP | URL / Endpoint | Port(s) | Usage |
| --- | --- | --- | --- | --- | --- |
| `ollama` | `vm210-ai-gpu` | `10.10.20.210` | `http://10.10.20.210:11434` | `11434` | Local LLM inference API for coding, chat, OCR, and automations |
| `open-webui` | `vm210-ai-gpu` | `10.10.20.210` | `http://10.10.20.210:3000` | `3000` | Browser UI and OpenAI-compatible API front door for Ollama models |
| `frigate` | `vm210-ai-gpu` | `10.10.20.210` | `http://10.10.20.210:5000` | `5000` default | NVR, object detection, and camera event review |
| `homeassistant` | `vm210-ai-gpu` | `10.10.20.210` | `http://10.10.20.210:8123` | `8123` default | Home automation, device integrations, dashboards |
| `wyoming-piper` | `vm210-ai-gpu` | `10.10.20.210` | `tcp://10.10.20.210:10200` | `10200` | Local Wyoming TTS service for Assist voice replies |
| `wyoming-whisper` | `vm210-ai-gpu` | `10.10.20.210` | `tcp://10.10.20.210:10300` | `10300` | Local Wyoming STT service for Assist speech recognition |
| `wyoming-openwakeword` | `vm210-ai-gpu` | `10.10.20.210` | `tcp://10.10.20.210:10400` | `10400` | Local Wyoming wake word service for voice pipelines |
| `n8n` | `vm210-ai-gpu` | `10.10.20.210` | `http://10.10.20.210:5678` | `5678` | Workflow automation and service orchestration |
| `openvscode-server` | `vm210-ai-gpu` | `10.10.20.210` | `http://10.10.20.210:3100` | `3100` | Remote VS Code-style editor for homelab work |
| `openclaw-gateway` | `vm300-openclaw` | `10.10.66.70` | `http://10.10.66.70:18789` | `18789` | OpenClaw AI agent gateway with Telegram bot integration, uses remote Ollama |
| `open-webui` | `vm300-openclaw` | `10.10.66.70` | `http://10.10.66.70:3000` | `3000` | Local Open WebUI instance connected to remote Ollama |
| `gluetun` | `lxc066-docker-arr` | `10.10.66.66` | `N/A` | `6881`, `6881/udp` | VPN sidecar and network gateway for the ARR/download stack |
| `qbittorrent` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:8085` | `8085` | Torrent client behind the VPN |
| `prowlarr` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:9696` | `9696` | Indexer management for the ARR stack |
| `sonarr` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:8989` | `8989` | TV automation |
| `radarr` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:7878` | `7878` | Movie automation |
| `lidarr` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:8686` | `8686` | Music automation |
| `bazarr` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:6767` | `6767` | Subtitle management |
| `readarr` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:8787` | `8787` | Book and ebook automation |
| `filebrowser` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:8081` | `8081` | File browser over the shared media tree |
| `jellyseerr` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:5055` | `5055` | Media request portal |
| `aurral` | `lxc066-docker-arr` | `10.10.66.66` | `http://10.10.66.66:3000` | `3000` | Audio/media workflow helper integrated with Lidarr |
| `immich-server` | `lxc200-docker-services` | `10.10.20.200` | `http://10.10.20.200:2283` | `2283` | Photo and video management |
| `immich-machine-learning` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | Immich ML worker |
| `immich-redis` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | Immich cache |
| `immich-postgres` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | Immich database |
| `owncloud` | `lxc200-docker-services` | `10.10.20.200` | `http://10.10.20.200:9090` | `9090` | File sync and collaboration |
| `owncloud_db` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | OwnCloud MariaDB |
| `owncloud_redis` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | OwnCloud Redis |
| `paperless` | `lxc200-docker-services` | `10.10.20.200` | `http://10.10.20.200:8000` | `8000` | Document management, OCR, and inbox workflow for scanned files |
| `paperless_db` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | Paperless-ngx PostgreSQL |
| `paperless_broker` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | Paperless-ngx Redis broker |
| `paperless_gotenberg` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | PDF conversion helper for Paperless-ngx |
| `paperless_tika` | `lxc200-docker-services` | `10.10.20.200` | `internal-only` | `N/A` | Text extraction helper for Paperless-ngx |
| `syncthing` | `lxc200-docker-services` | `10.10.20.200` | `http://10.10.20.200:8384` | `8384`, `22000/tcp`, `22000/udp`, `21027/udp` | Sync service for important data between systems |
| `blinko` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:1111` | `1111` | Notes or knowledge app with Ollama integration |
| `blinko-db` | `lxc220-docker-apps` | `10.10.20.220` | `internal-only` | `N/A` | Blinko PostgreSQL |
| `calibre-web` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:8084` | `8084` | Web frontend for ebook library browsing |
| `calibre` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:8083` | `8083`, `8181` | Calibre server and ebook management |
| `erugo` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:9998` | `9998` | General web application storage/service |
| `firefly_iii_core` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:8011` | `8011` | Personal finance tracking |
| `firefly_iii_db` | `lxc220-docker-apps` | `10.10.20.220` | `internal-only` | `N/A` | Firefly III database |
| `grafana` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:3000` | `3000` | Dashboards and metrics visualization |
| `grist` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:8484` | `8484` | Spreadsheet/database hybrid app |
| `homarr` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:7575` | `7575` | Homelab dashboard |
| `influxdb` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:8086` | `8086` | Time-series database |
| `node-red` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:1880` | `1880` | Visual automation flows |
| `pairdrop` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:1010` | `1010` | Local file sharing in browser |
| `teslamate` | `lxc220-docker-apps` | `10.10.20.220` | `http://10.10.20.220:4000` | `4000` | Tesla telemetry and trip analysis |
| `teslamate_postgres` | `lxc220-docker-apps` | `10.10.20.220` | `postgres://10.10.20.220:5432` | `5432` | TeslaMate database |
| `jellyfin` | `lxc230-docker-media` | `10.10.20.230` | `http://10.10.20.230:8096` | `8096` | Media server |
| `plex` | `lxc230-docker-media` | `10.10.20.230` | `http://10.10.20.230:32400/web` | `32400` | Media server |
| `tailscale` | `lxc230-docker-media` | `10.10.20.230` | `internal-only` | `N/A` | Network namespace for Jellyswarrm |
| `jellyswarrm` | `lxc230-docker-media` | `10.10.20.230` | `tailscale-only` | `N/A` | Proxy or remote access helper for media apps |
| `cloudflare-ddns-all` | `lxc240-docker-external` | `10.10.66.240` | `internal-only` | `N/A` | Cloudflare DDNS for wildcard DNS |
| `cloudflare-ddns-all-uk` | `lxc240-docker-external` | `10.10.66.240` | `internal-only` | `N/A` | Cloudflare DDNS for `*.uk` |
| `cloudflare-ddns-uk` | `lxc240-docker-external` | `10.10.66.240` | `internal-only` | `N/A` | Cloudflare DDNS for `uk` |
| `cloudflare-ddns-art` | `lxc240-docker-external` | `10.10.66.240` | `internal-only` | `N/A` | Cloudflare DDNS for `art` |
| `ghost` | `lxc240-docker-external` | `10.10.66.240` | `http://10.10.66.240:2368` | `2368` | Ghost blog/CMS |
| `kutt` | `lxc240-docker-external` | `10.10.66.240` | `http://10.10.66.240:7070` | `7070` | URL shortener |
| `nginx` | `lxc240-docker-external` | `10.10.66.240` | `http://10.10.66.240` / `https://10.10.66.240` | `80`, `443` | Reverse proxy and public entry point |
| `rustdesk_tailscale` | `lxc240-docker-external` | `10.10.66.240` | `tailscale-only` | `N/A` | Tailscale network for RustDesk services |
| `rustdesk_id` | `lxc240-docker-external` | `10.10.66.240` | `tailscale-only` | `N/A` | RustDesk ID server |
| `rustdesk_relay` | `lxc240-docker-external` | `10.10.66.240` | `tailscale-only` | `UDP 40000` via pfSense/Tailscale path | RustDesk relay server |
| `tailscale-peer-relay` | `lxc240-docker-external` | `10.10.66.240` | `tailscale-only` | `host network` | Tailscale peer relay |
| `walletpage` | `lxc240-docker-external` | `10.10.66.240` | `http://10.10.66.240:8070` | `8070` | Static wallet or landing page |
| `wordpress` | `lxc240-docker-external` | `10.10.66.240` | `http://10.10.66.240:8080` | `8080` | WordPress site |
| `wordpress_db` | `lxc240-docker-external` | `10.10.66.240` | `internal-only` | `N/A` | WordPress MariaDB |
| `alertmanager` | `lxc250-infra` | `10.10.20.250` | `http://10.10.20.250:9093` | `9093` | Alert routing and notification hub |
| `grafana` | `lxc250-infra` | `10.10.20.250` | `http://10.10.20.250:3000` | `3000` | Infra dashboards and monitoring UI |
| `homebridge` | `lxc250-infra` | `10.10.20.250` | `http://10.10.20.250:8582` | `8582` | HomeKit bridge service |
| `mosquitto` | `lxc250-infra` | `10.10.20.250` | `mqtt://10.10.20.250:1883` | `1883`, `9001` | MQTT broker for automation and sensors |
| `portainer` | `lxc250-infra` | `10.10.20.250` | `https://10.10.20.250:9443` | `9443`, `8001` | Docker management UI for local container administration |
| `prometheus` | `lxc250-infra` | `10.10.20.250` | `http://10.10.20.250:9090` | `9090` | Metrics scraping and storage |
| `ansible-semaphore` | `lxc250-infra` | `10.10.20.250` | `http://10.10.20.250:3002` | `3002` | Ansible job UI and automation runner |
| `uptime-kuma` | `lxc250-infra` | `10.10.20.250` | `http://10.10.20.250:3001` | `3001` | Uptime monitoring and status checks |

## Notes

| Topic | Detail |
| --- | --- |
| Reverse proxy | Public HTTP and HTTPS are intended to terminate on `lxc240-docker-external` via `nginx` |
| Site-aware addressing | Host IDs stay constant while the second octet comes from `site_config.yml`, so UK defaults are `10.10.x.x` and France builds become `10.20.x.x` |
| AI API front door | `open-webui` is the intended single API/UI front door for local models |
| Port reuse | Some services share the same port number on different hosts, for example `3000` on both `vm210-ai-gpu` and `lxc250-infra` |
| Internal helpers | Databases, Redis, and sidecars are listed for completeness but are not usually user-facing |
