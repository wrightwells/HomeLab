#!/usr/bin/env bash
# prepare-lxc-storage.sh -- Create ZFS bind-mount directories on the Proxmox host.
#
# Unprivileged LXCs cannot chown ZFS bind-mount paths. This script creates all
# required directories on the Proxmox host with 777 permissions so that
# containers can read/write without ownership issues.
#
# Run this on the Proxmox host AFTER storage is set up (step 3) and BEFORE
# running Ansible (step 10).
#
# Usage: ./scripts/prepare-lxc-storage.sh

set -euo pipefail

echo "=== Creating LXC bind-mount directories on Proxmox host ==="

# ---------------------------------------------------------------------------
# Appdata directories
# ---------------------------------------------------------------------------
echo "Creating /mnt/appdata directories..."
mkdir -p /mnt/appdata/docker_volumes
mkdir -p /mnt/appdata/configs
mkdir -p /mnt/appdata/homelab-control
mkdir -p /mnt/appdata/openvscode/config
mkdir -p /mnt/appdata/code
chmod 777 /mnt/appdata /mnt/appdata/docker_volumes /mnt/appdata/configs /mnt/appdata/homelab-control

# Docker volume subdirectories (shared across all LXCs)
echo "Creating Docker volume subdirectories..."
mkdir -p /mnt/appdata/docker_volumes/{gluetun,qbittorrent,prowlarr,sonarr,radarr,lidarr,bazarr,readarr,filebrowser,jellyseerr,aurral}
mkdir -p /mnt/appdata/docker_volumes/{jellyfin,plex,jellyswarrm/tailscale}
mkdir -p /mnt/appdata/docker_volumes/{immich/immich_db,immich/immich_ml,immich/immich_redis,immich/immich_library}
mkdir -p /mnt/appdata/docker_volumes/{owncloud/config,owncloud/mysql,owncloud/redis,owncloud/data}
mkdir -p /mnt/appdata/docker_volumes/{paperless-ngx/db,paperless-ngx/data,paperless-ngx/media,paperless-ngx/export,paperless-ngx/consume}
mkdir -p /mnt/appdata/docker_volumes/{syncthing/config}
mkdir -p /mnt/appdata/docker_volumes/{syncthing_sync}
mkdir -p /mnt/appdata/docker_volumes/{mqtt,homebridge,portainer,prometheus,grafana,alertmanager,uptime-kuma,semaphore/postgres}
mkdir -p /mnt/appdata/docker_volumes/{blinko/blinko-db,calibre,calibre-web,grist,homarr,node-red,influxdb,pairdrop,erugo,finance/db,teslamate/postgres}
mkdir -p /mnt/appdata/docker_volumes/{ghost,kutt/db,wordpress/wordpress_db,rustdesk_id,rustdesk_relay,rustdesk_tailscale}
mkdir -p /mnt/appdata/docker_volumes/{cloudflare-ddns-all,walletpage,open-webui,ollama,n8n,frigate,home-assistant,home-assistant-voice/piper,home-assistant-voice/whisper,home-assistant-voice/openwakeword,home-assistant-voice/openwakeword/custom,openvscode-server}
chmod -R 777 /mnt/appdata/docker_volumes

# ---------------------------------------------------------------------------
# AI model storage
# ---------------------------------------------------------------------------
echo "Creating /mnt/ai_models directory..."
mkdir -p /mnt/ai_models/ollama
mkdir -p /mnt/ai_models/cache
chmod 777 /mnt/ai_models /mnt/ai_models/ollama /mnt/ai_models/cache

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
echo ""
echo "=== Verifying directories ==="
echo "Appdata: $(ls -ld /mnt/appdata | awk '{print $1, $9}')"
echo "AI models: $(ls -ld /mnt/ai_models | awk '{print $1, $9}')"
echo ""
echo "=== LXC storage preparation complete ==="
