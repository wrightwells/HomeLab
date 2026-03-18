# Adding a Docker Component

This guide explains how to add a new Dockerized application so the existing
Ansible structure can deploy it onto one of the Docker-capable hosts.

## 1. Choose the target host group

Decide which host should run the new component. Current Docker bundle groups are:

- `lxc066-docker-arr`
- `lxc200-docker-services`
- `lxc220-docker-apps`
- `lxc230-docker-media`
- `lxc240-docker-external`
- `lxc250-infra`
- `vm210-ai-gpu`

Pick the bundle directory that matches the destination host.

## 2. Add the compose directory

Create a new directory under:

```text
ansible/files/compose/<bundle-name>/<component-name>/
```

Example:

```text
ansible/files/compose/lxc220-docker-apps/my-service/
```

At minimum, add:

- `docker-compose.yml`

Add one of these if the stack needs environment variables:

- `stack.env.vault` for encrypted secrets
- `stack.env.example` for non-secret defaults or placeholders

If both exist, Ansible will prefer `stack.env.vault` and decrypt it to
`stack.env` on the target host at deploy time.

## 3. Write the compose file correctly

Inside `docker-compose.yml`:

- Use `env_file: stack.env` if the stack depends on values from the env file.
- Keep host paths aligned with the repo conventions, for example:
  - `/mnt/appdata`
  - `/mnt/media_pool`
  - `/mnt/ai_models`
  - `/mnt/ai_cache`
- Avoid hardcoding secrets directly in the compose file.
- Prefer service-specific `container_name` values to avoid collisions.

If the stack does not use any environment file, you do not need
`stack.env.example` or `stack.env.vault`.

## 4. Update the Ansible role for that host

Open the host role task file and add the new component to `compose_stacks`.

Examples:

- [main.yml](/home/ww/HomeLab/HomeLab/ansible/roles/lxc220-docker-apps/tasks/main.yml)
- [main.yml](/home/ww/HomeLab/HomeLab/ansible/roles/lxc240-docker-external/tasks/main.yml)
- [main.yml](/home/ww/HomeLab/HomeLab/ansible/roles/vm210-ai-gpu/tasks/main.yml)

Example change:

```yaml
- name: Deploy compose bundles for docker-apps
  ansible.builtin.include_role:
    name: docker
    tasks_from: deploy_compose_bundle.yml
  vars:
    compose_bundle_name: lxc220-docker-apps
    compose_stacks:
      - grafana
      - my-service
```

If you forget this step, Ansible will never deploy the new component.

## 5. Check whether host variables are needed

Review:

- [all.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/group_vars/all.yml)
- [docker_external.yml](/home/ww/HomeLab/HomeLab/ansible/group_vars/docker_external.yml)
- [vault.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/group_vars/vault.yml)

Update these only if the new stack needs shared settings that are not already
carried in `stack.env`.

General rule:

- Put stack-local secrets in `stack.env.vault`
- Put shared inventory-wide settings in group vars

## 6. Check whether the playbook already covers the host

The top-level playbook already targets each Docker host role:

- [site.yml](/home/ww/HomeLab/HomeLab/ansible/playbooks/site.yml)

Usually you do not need to change the playbook when adding a component to an
existing host bundle.

You only need to update `site.yml` if:

- you create a brand-new host role
- you add a brand-new host group

## 7. If this is a brand-new Docker host

If the new component is going onto a host that does not already exist in the
repo, update all of the following:

1. Terraform host/module configuration under `terraform/`
2. The generated inventory source in Terraform
3. The Ansible inventory if you are not regenerating it yet
4. A new Ansible role under `ansible/roles/<host-role>/`
5. [site.yml](/home/ww/HomeLab/HomeLab/ansible/playbooks/site.yml) to include that role

For existing hosts, you do not need these extra steps.

## 8. Validate before running

Run:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml --syntax-check
```

If you changed Terraform inventory generation, also run:

```bash
terraform -chdir=terraform validate
```

## 9. Deploy

Make sure your vault password file is available, then run:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=~/.config/ansible/homelab-vault-pass.txt ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml
```

## Checklist

- Compose directory created in `ansible/files/compose/<bundle>/<component>/`
- `docker-compose.yml` added
- `stack.env.vault` or `stack.env.example` added if needed
- Target role updated in `ansible/roles/.../tasks/main.yml`
- Shared vars updated only if necessary
- `site.yml` updated only if a new host role was introduced
- Ansible syntax check passed
