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
- Terraform should be run first so it can render the Ansible inventory.

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

Note:

- The current repo does not format or assemble those host disks automatically.
- Terraform consumes existing Proxmox datastores and existing host mount paths.
- See the storage guide for the full process.

## Guides

- [Bootstrap Guide](README-bootstrap.md)
- [Storage Guide](README-storage.md)
- [Sizing Guide](README-sizing.md)
- [Session Prompt](README-session-prompt.md)
- [Service Catalog](README-services.md)
- [Add Docker Component](README-add-docker-component.md)
- [Semaphore Guide](README-semaphore.md)
- [Stack Env Vault Script](README-stack-env-vaults.md)
- [Continue Config Example](continue/config.yaml.example)
  This is a local client-side example and is not part of the automated deployment.
