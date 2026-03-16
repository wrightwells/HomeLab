# HomeLab
#
# Infrastructure-as-code repository for a Proxmox-based homelab.
#
# Planned hosts:
# - VM100 pfSense
# - VM210 AI-GPU
# - LXC066 docker-arr
# - LXC200 docker-services
# - LXC220 docker-apps
# - LXC230 docker-media
# - LXC240 docker-external
# - LXC250 infra
#
# Structure:
# - terraform/   -> Proxmox infrastructure
# - ansible/     -> host configuration
# - docs/        -> design notes and diagrams
# - scripts/     -> helper commands
