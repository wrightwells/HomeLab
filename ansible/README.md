# Ansible

Terraform renders the inventory to:

`inventories/production/hosts.ini`

Before the first Terraform run, that file also acts as the seed inventory for
bootstrap playbooks that target the Proxmox host itself. For the current
network layout, `proxmox-host` should use the bootstrap/uplink address on
`nic0`, for example `10.10.1.10`.

The preferred execution point for the main site playbook is the Proxmox host
itself. That keeps bootstrap-time guest reachability simple while pfSense and
the VLAN-backed networks are still coming online.

Run:

```bash
ansible-galaxy collection install -r requirements.yml
ansible all -m ping
ansible-playbook playbooks/site.yml
```

From your workstation, use these wrappers when you need to drive the
host-local control-node path remotely:

```bash
./scripts/ensure-proxmox-host-ansible.sh
./scripts/run-ansible-on-proxmox-host.sh --limit ai_gpu
```

The `ensure-proxmox-host-ansible.sh` helper also synchronizes the Proxmox
host's dedicated guest-access public key into
`terraform/generated/proxmox-host-control.auto.tfvars.json` so subsequent
Terraform runs can seed that key into fresh guests automatically.

## AI GPU notes

`ai-gpu` now carries its guest-side GPU bootstrap in Ansible:

- the `vm210-ai-gpu` role installs the NVIDIA driver and `nvidia-container-toolkit`
- the role runs `nvidia-ctk runtime configure --runtime=docker`
- the role reboots the VM when the driver/toolkit install changes
- the role verifies both `nvidia-smi` on the host and `docker run --gpus all ... nvidia-smi`

The inventory also pins `ansible_remote_tmp=/var/tmp/ansible-remote` for
`ai-gpu`, because `/tmp/ansible-remote` was previously created as `root` during
bootstrap and broke module staging for the unprivileged `ansible` user.
