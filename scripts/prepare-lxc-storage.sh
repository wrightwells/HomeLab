#!/usr/bin/env bash
# prepare-lxc-storage.sh -- Create ZFS bind-mount directories on the Proxmox host.
#
# Unprivileged LXCs cannot chown ZFS bind-mount paths. This script creates all
# required directories on the Proxmox host with 777 permissions so that
# containers can read/write without ownership issues.
#
# IMPORTANT: Several services now use host bind mounts under
# /mnt/appdata/docker_volumes, including some database and state paths.
# These host directories must exist before Ansible deploys Compose stacks,
# otherwise Docker inside unprivileged LXCs can fail with permission denied
# while trying to create new top-level mount source paths on the shared ZFS
# bind mount.
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
# Docker volume subdirectories
# ---------------------------------------------------------------------------
echo "Creating Docker volume subdirectories..."

# ARR stack (lxc066-docker-arr)
mkdir -p /mnt/appdata/docker_volumes/{gluetun,qbittorrent,prowlarr,sonarr,radarr,lidarr,bazarr,readarr,filebrowser,jellyseerr,aurral}

# Media stack (lxc230-docker-media)
mkdir -p /mnt/appdata/docker_volumes/{jellyfin,plex,jellyswarrm/tailscale}

# Services stack (lxc200-docker-services)
mkdir -p /mnt/appdata/docker_volumes/{immich/db,immich/model-cache}
mkdir -p /mnt/appdata/docker_volumes/{owncloud/data,owncloud/db}
mkdir -p /mnt/appdata/docker_volumes/{paperless-ngx/db,paperless-ngx/data,paperless-ngx/media,paperless-ngx/export,paperless-ngx/consume}
mkdir -p /mnt/appdata/docker_volumes/syncthing/config
mkdir -p /mnt/appdata/docker_volumes/syncthing_sync

# Apps stack (lxc220-docker-apps)
mkdir -p /mnt/appdata/docker_volumes/{homarr,influxdb,pairdrop}
mkdir -p /mnt/appdata/docker_volumes/{blinko/db,blinko/files}
mkdir -p /mnt/appdata/docker_volumes/{calibre/config,calibre-web/config}
mkdir -p /mnt/appdata/docker_volumes/erugo/storage
mkdir -p /mnt/appdata/docker_volumes/grist-finance-connector/state
mkdir -p /mnt/appdata/docker_volumes/node-red
mkdir -p /mnt/appdata/docker_volumes/teslamate/db

# External stack (lxc240-docker-external)
mkdir -p /mnt/appdata/docker_volumes/{ghost/content,kutt/db}
mkdir -p /mnt/appdata/docker_volumes/{nginx/html,nginx/logs}
mkdir -p /mnt/appdata/docker_volumes/{rustdesk/data,rustdesk/tailscale-state}
mkdir -p /mnt/appdata/docker_volumes/tailscale-peer-relay/state
mkdir -p /mnt/appdata/docker_volumes/walletpage
mkdir -p /mnt/appdata/docker_volumes/{wordpress/html,wordpress/db}

# Infra stack (lxc250-infra)
mkdir -p /mnt/appdata/docker_volumes/{portainer,prometheus/data,uptime-kuma}
mkdir -p /mnt/appdata/docker_volumes/{mosquitto/config,mosquitto/data,mosquitto/log}

# AI GPU VM (vm210-ai-gpu)
mkdir -p /mnt/appdata/docker_volumes/{open-webui,frigate,home-assistant,portainer}
mkdir -p /mnt/appdata/docker_volumes/{home-assistant-voice/piper,home-assistant-voice/whisper,home-assistant-voice/openwakeword,home-assistant-voice/openwakeword/custom}
mkdir -p /mnt/appdata/docker_volumes/{n8n,openvscode-server,searxng/config}
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
mkdir -p /mnt/media_pool/{books,music,movies,photos,tv}
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
echo "Note: Shared bind-mounted appdata paths must be pre-created on the Proxmox"
echo "host. Unprivileged LXCs can otherwise hit permission-denied errors when"
echo "Docker tries to create new top-level mount source directories at runtime."
