# HomeLab

Infrastructure-as-code repository for a Proxmox homelab.

## Before You Run

Create an Ansible vault password file on the machine that will run the playbooks.
This password is used to decrypt any `stack.env.vault` files during deployment and
write them to the target hosts as plain `stack.env` files.

Example setup:

```bash
mkdir -p ~/.config/ansible
printf '%s\n' 'REPLACE_WITH_YOUR_VAULT_PASSWORD' > ~/.config/ansible/homelab-vault-pass.txt
chmod 600 ~/.config/ansible/homelab-vault-pass.txt
```

Run Ansible with:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=~/.config/ansible/homelab-vault-pass.txt ansible-playbook ansible/playbooks/site.yml
```

Notes:

- Do not commit the vault password file.
- If you prefer an interactive prompt, use `ansible-playbook --ask-vault-pass`.
- Terraform should be run first so it can render the Ansible inventory from the current build inventory.

## Build Inventory

The repo now keeps the full homelab definition in place while letting you build
only the pieces you want.

Use [build_inventory.yml](ansible/inventories/production/build_inventory.yml)
to control:

- which guests are included in the generated build
- which Docker bundles are enabled on each guest
- which logical storage mounts are expected
- which backing stores are enabled for the current hardware layout

Example use cases:

- full build with every guest and service enabled
- lightweight build with only `vm100_pfsense`, `lxc230_docker_media`, and a few core services
- reduced storage build where `/mnt/appdata` still exists but falls back to `host_os` instead of a separate appdata disk

Use [site_config.yml](ansible/inventories/production/site_config.yml) to control:

- whether the build is UK or France
- the second IP octet, for example `10.10.x.x` for UK or `10.20.x.x` for France
- the domain suffix such as `uk.linux` or `fr.linux`
- VLAN-backed subnet ranges used by Terraform and generated inventory

## Hosts

- VM100 pfSense
- VM050 Mint desktop
- VM210 AI-GPU
- LXC066 docker-arr
- LXC200 docker-services
- LXC220 docker-apps
- LXC230 docker-media
- LXC240 docker-external
- LXC250 infra

All of these remain defined in the repo. Inclusion in a given build is driven by
the build inventory file rather than by deleting repo configuration.

## Storage model

- NVMe 500GB: /mnt/ai_models, /mnt/ai_cache, Frigate recordings, LLM cache
- SSD 500GB: Proxmox OS, Terraform repo, LXC rootfs, VM root disks, Docker runtime
- RAID1 2x4TB: /mnt/appdata for config, databases, Docker volumes, Syncthing critical data
- Media pool 4x12TB: /mnt/media_pool via mergerfs

Note:

- The current repo does not format or assemble those host disks automatically.
- Terraform consumes existing Proxmox datastores and existing host mount paths.
- The build inventory describes which logical stores are enabled and whether a mount should prefer a dedicated disk or fall back to `host_os`.
- See the storage guide for the full process.

## Guides

- [Bootstrap Guide](README-bootstrap.md)
- [Storage Guide](README-storage.md)
- [Sizing Guide](README-sizing.md)
- [Build Inventory Guide](README-build-inventory.md)
- [Build Inventory](ansible/inventories/production/build_inventory.yml)
- [Site Config](ansible/inventories/production/site_config.yml)
- [Session Prompt](README-session-prompt.md)
- [Service Catalog](README-services.md)
- [Home Assistant Voice Stack](docs/home-assistant-voice-stack.md)
- [Home Assistant Ollama Setup](docs/home-assistant-ollama.md)
- [Add Docker Component](README-add-docker-component.md)
- [Semaphore Guide](README-semaphore.md)
- [Stack Env Vault Script](README-stack-env-vaults.md)
- [Continue Config Example](continue/config.yaml.example)
  This is a local client-side example and is not part of the automated deployment.
