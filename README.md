# HomeLab

Infrastructure-as-code repository for a Proxmox homelab.

## Hosts

- VM100 pfSense
- VM210 AI-GPU
- LXC066 docker-arr
- LXC200 docker-services
- LXC220 docker-apps
- LXC230 docker-media
- LXC240 docker-external
- LXC250 infra

## Storage model

- NVMe 500GB: /mnt/ai_models, /mnt/ai_cache, Frigate recordings, LLM cache
- SSD 500GB: Proxmox OS, Terraform repo, LXC rootfs, VM root disks, Docker runtime
- RAID1 2x4TB: /mnt/appdata for config, databases, Docker volumes, Syncthing critical data
- Media pool 4x12TB: /mnt/media_pool via mergerfs
