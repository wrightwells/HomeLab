# Ansible

Terraform renders the inventory to:

`inventories/production/hosts.yml`

Run:

```bash
ansible all -m ping
ansible-playbook playbooks/site.yml
```
