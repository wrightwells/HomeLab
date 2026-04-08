#!/usr/bin/env bash
# prepare-lxc-storage.sh -- Create ZFS bind-mount directories on the Proxmox host.
#
# Unprivileged LXCs cannot chown ZFS bind-mount paths. This script creates all
# required directories on the Proxmox host with 777 permissions so that
# containers can read/write without ownership issues.
#
# IMPORTANT: Database containers (postgres, mariadb) now use Docker named
# volumes instead of bind mounts to avoid ZFS chown failures. Only non-database
# paths need host directories.
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

# ---------------------------------------------------------------------------
# Docker volume subdirectories (non-database paths only)
# Database containers use Docker named volumes to avoid ZFS chown issues
# ---------------------------------------------------------------------------
echo "Creating Docker volume subdirectories..."

# ARR stack (lxc066-docker-arr)
mkdir -p /mnt/appdata/docker_volumes/{gluetun,qbittorrent,prowlarr,sonarr,radarr,lidarr,bazarr,readarr,filebrowser,jellyseerr,aurral}

# Media stack (lxc230-docker-media)
mkdir -p /mnt/appdata/docker_volumes/{jellyfin,plex,jellyswarrm/tailscale}

# Services stack (lxc200-docker-services) -- data/media paths only, no DB paths
mkdir -p /mnt/appdata/docker_volumes/{owncloud/config,owncloud/data}
mkdir -p /mnt/appdata/docker_volumes/{paperless-ngx/data,paperless-ngx/media,paperless-ngx/export,paperless-ngx/consume}
mkdir -p /mnt/appdata/docker_volumes/{syncthing/config}
mkdir -p /mnt/appdata/docker_volumes/syncthing_sync

# Apps stack (lxc220-docker-apps) -- no DB paths (use named volumes)
mkdir -p /mnt/appdata/docker_volumes/{calibre,calibre-web,grist,homarr,influxdb,pairdrop,erugo}
mkdir -p /mnt/appdata/docker_volumes/{blinko/files}
mkdir -p /mnt/appdata/docker_volumes/{node-red}

# External stack (lxc240-docker-external) -- no DB paths
mkdir -p /mnt/appdata/docker_volumes/{ghost,kutt,walletpage,nginx}
mkdir -p /mnt/appdata/docker_volumes/{rustdesk_id,rustdesk_relay,rustdesk_tailscale}
mkdir -p /mnt/appdata/docker_volumes/{cloudflare-ddns-all,wordpress/data}

# Infra stack (lxc250-infra) -- no DB paths
mkdir -p /mnt/appdata/docker_volumes/{portainer,prometheus/data,uptime-kuma}
mkdir -p /mnt/appdata/docker_volumes/{mosquitto/config,mosquitto/data,mosquitto/log}

# AI GPU VM (vm210-ai-gpu) -- no DB paths
mkdir -p /mnt/appdata/docker_volumes/{open-webui,frigate,home-assistant}
mkdir -p /mnt/appdata/docker_volumes/{home-assistant-voice/piper,home-assistant-voice/whisper,home-assistant-voice/openwakeword,home-assistant-voice/openwakeword/custom}
mkdir -p /mnt/appdata/docker_volumes/{n8n,openvscode-server}
chmod -R 777 /mnt/appdata/docker_volumes

# ---------------------------------------------------------------------------
# Config directories (for non-docker-config files)
# ---------------------------------------------------------------------------
echo "Creating config directories..."
mkdir -p /mnt/appdata/configs/{alertmanager,prometheus,mosquitto,homebridge,node-red}
mkdir -p /mnt/appdata/configs/tailscale-ai
chmod -R 777 /mnt/appdata/configs

# ---------------------------------------------------------------------------
# AI model storage
# ---------------------------------------------------------------------------
echo "Creating /mnt/ai_models directory..."
mkdir -p /mnt/ai_models/ollama
mkdir -p /mnt/ai_models/cache
chmod 777 /mnt/ai_models /mnt/ai_models/ollama /mnt/ai_models/cache

# ---------------------------------------------------------------------------
# Tailscale state (for ai-gpu Tailscale container)
# ---------------------------------------------------------------------------
echo "Creating /mnt/appdata/tailscale directory..."
mkdir -p /mnt/appdata/tailscale/ai/state
chmod 777 /mnt/appdata/tailscale/ai/state

# ---------------------------------------------------------------------------
# Media pool directories (created by proxmox-storage.yml via MergerFS,
# but also created here as a safety net so containers don't fail)
# ---------------------------------------------------------------------------
echo "Creating media pool directories..."
mkdir -p /mnt/media_pool/{books,music,movies,tv}
mkdir -p /mnt/media_pool/torrents/{books,music,movies,tv,incomplete}
chmod -R 777 /mnt/media_pool 2>/dev/null || true

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
echo ""
echo "=== Verifying key directories ==="
for dir in /mnt/appdata/docker_volumes /mnt/appdata/configs /mnt/ai_models; do
  if [ -d "$dir" ]; then
    echo "EXISTS: $dir ($(stat -c '%a' "$dir"))"
  else
    echo "MISSING: $dir"
  fi
done

echo ""
echo "=== LXC storage preparation complete ==="
echo ""
echo "Note: Database containers (postgres, mariadb, redis) use Docker named"
echo "volumes and do NOT require host directories. This avoids ZFS chown failures"
echo "in unprivileged LXCs where root maps to nobody:65534 on the host."
