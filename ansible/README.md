# Ansible

Terraform renders the inventory to:

`inventories/production/hosts.ini`

Run:

```bash
ansible-galaxy collection install -r requirements.yml
ansible all -m ping
ansible-playbook playbooks/site.yml
```
