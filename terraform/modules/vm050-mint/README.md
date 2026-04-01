# vm050-mint

Linux Mint Cinnamon desktop VM cloned from a prepared Proxmox template.

The module provisions:

- a clone-based desktop VM
- a root disk
- an NVMe-style data disk for `/mnt/ai_models` and `/mnt/ai_cache`
- a media-style data disk for `/mnt/media_pool`
- a single network interface on the trusted bridge (`vmbr2` by default) with a site-driven VLAN and IP
