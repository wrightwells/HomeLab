# Ansible

Terraform renders the inventory to:

`inventories/production/hosts.ini`

Before the first Terraform run, that file also acts as the seed inventory for
bootstrap playbooks that target the Proxmox host itself. For the current
network layout, `proxmox-host` should use the bootstrap/uplink address on
`nic0`, for example `10.10.1.10`.

Run:

```bash
ansible-galaxy collection install -r requirements.yml
ansible all -m ping
ansible-playbook playbooks/site.yml
```
