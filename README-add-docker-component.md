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

## 4. Decide which host folders the stack needs

Before deployment, identify every bind-mounted host path in the compose file.

Examples:

- config/data on mirrored app storage:
  - `/mnt/appdata/docker_volumes/<service>`
  - `/mnt/appdata/configs/<service>`
- fast AI storage:
  - `/mnt/ai_models/<service>`
  - `/mnt/ai_cache/<service>`
- shared media:
  - `/mnt/media_pool/...`

General rule:

- Use `/mnt/appdata/...` for persistent app config and state
- Use `/mnt/ai_models/...` or `/mnt/ai_cache/...` only for AI-specific fast-storage needs
- Use `/mnt/media_pool/...` for shared media libraries, downloads, and imports

The shared base folders are created by the Proxmox host storage bootstrap:

- `/mnt/appdata/docker_volumes`
- `/mnt/appdata/configs`
- `/mnt/media_pool/books`
- `/mnt/media_pool/music`
- `/mnt/media_pool/movies`
- `/mnt/media_pool/tv`
- `/mnt/media_pool/torrents`
- `/mnt/media_pool/torrents/books`
- `/mnt/media_pool/torrents/music`
- `/mnt/media_pool/torrents/movies`
- `/mnt/media_pool/torrents/tv`
- `/mnt/media_pool/torrents/incomplete`

Application-specific subfolders under those paths should be declared in Ansible
so they are created before Docker starts.

## 5. Declare host folders in the Ansible role

If the stack writes to host bind mounts, add those paths to `docker_host_paths`
in the target role's `include_role` block.

Example:

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
    docker_host_paths:
      - path: /mnt/appdata/docker_volumes/my-service
        owner: "{{ docker_app_uid }}"
        group: "{{ docker_app_gid }}"
      - path: /mnt/appdata/configs/my-service
        owner: "{{ docker_app_uid }}"
        group: "{{ docker_app_gid }}"
```

The Docker deployment role will create those paths before `docker compose` runs.

Use `docker_app_uid` and `docker_app_gid` for containers that run as
`PUID=1000` / `PGID=1000`.

Use default root ownership when:

- the container runs as root
- the mount is read-only
- the image does not support `PUID` / `PGID`

If you need a file instead of a directory, declare it explicitly:

```yaml
    docker_host_paths:
      - path: /mnt/appdata/docker_volumes/filebrowser/settings.json
        state: touch
        owner: "{{ docker_app_uid }}"
        group: "{{ docker_app_gid }}"
        mode: "0644"
```

## 6. Update the Ansible role for that host

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

## 7. Check whether the compose file needs `PUID` / `PGID`

If the image supports running as a non-root user, add:

```yaml
environment:
  - PUID=1000
  - PGID=1000
```

or, if the stack already uses `stack.env`:

```yaml
environment:
  - PUID=${PUID}
  - PGID=${PGID}
```

and put the values in `stack.env.example` or `stack.env.vault`.

Only do this for images that actually support the LinuxServer-style `PUID` /
`PGID` pattern. Do not add it blindly to every image.

## 8. Check whether host variables are needed

Review:

- [all.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/group_vars/all.yml)
- [docker_external.yml](/home/ww/HomeLab/HomeLab/ansible/group_vars/docker_external.yml)
- [vault.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/group_vars/vault.yml)

Update these only if the new stack needs shared settings that are not already
carried in `stack.env`.

General rule:

- Put stack-local secrets in `stack.env.vault`
- Put shared inventory-wide settings in group vars

## 9. Check whether the playbook already covers the host

The top-level playbook already targets each Docker host role:

- [site.yml](/home/ww/HomeLab/HomeLab/ansible/playbooks/site.yml)

Usually you do not need to change the playbook when adding a component to an
existing host bundle.

You only need to update `site.yml` if:

- you create a brand-new host role
- you add a brand-new host group

## 10. If this is a brand-new Docker host

If the new component is going onto a host that does not already exist in the
repo, update all of the following:

1. Terraform host/module configuration under `terraform/`
2. The generated inventory source in Terraform
3. The Ansible inventory if you are not regenerating it yet
4. A new Ansible role under `ansible/roles/<host-role>/`
5. [site.yml](/home/ww/HomeLab/HomeLab/ansible/playbooks/site.yml) to include that role

For existing hosts, you do not need these extra steps.

## 11. Validate before running

Run:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml --syntax-check
```

If you changed Terraform inventory generation, also run:

```bash
terraform -chdir=terraform validate
```

## 12. Deploy

Make sure your vault password file is available, then run:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=~/.config/ansible/homelab-vault-pass.txt ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml
```

## Checklist

- Compose directory created in `ansible/files/compose/<bundle>/<component>/`
- `docker-compose.yml` added
- `stack.env.vault` or `stack.env.example` added if needed
- Host bind-mount folders identified
- `docker_host_paths` added for writable bind mounts
- `PUID` / `PGID` added only if the image supports it
- Target role updated in `ansible/roles/.../tasks/main.yml`
- Shared vars updated only if necessary
- `site.yml` updated only if a new host role was introduced
- Ansible syntax check passed
