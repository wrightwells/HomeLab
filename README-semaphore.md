# Semaphore Guide

This guide explains how the `Semaphore` stack is intended to manage this repo
for recurring Terraform and Ansible checks.

The weekly check scripts are intended to be called by scheduled tasks in the
Semaphore GUI.

## What Has Been Added

The `Semaphore` bundle in:

- [docker-compose.yml](ansible/files/compose/lxc250-infra/semaphore/docker-compose.yml)

now uses a custom image built from:

- [Dockerfile](ansible/files/compose/lxc250-infra/semaphore/Dockerfile)

That image installs:

- `git`
- `ansible`
- `terraform`

The container also mounts:

- `/mnt/appdata/docker_volumes/semaphore` -> Semaphore data
- `/mnt/appdata/docker_volumes/semaphore/postgres` -> Semaphore PostgreSQL data
- `/mnt/appdata/docker_volumes/semaphore/workspace` -> working directory for repo clones
- `/mnt/appdata/docker_volumes/semaphore/.config/ansible` -> Ansible config directory for the vault password file
- `/mnt/appdata/docker_volumes/semaphore/tmp` -> temporary playbook path for Semaphore jobs

The stack now also includes a dedicated PostgreSQL service for Semaphore.

## Helper Scripts For Semaphore Jobs

Two repo scripts are intended for scheduled Semaphore jobs:

- [semaphore-weekly-terraform-plan.sh](scripts/semaphore-weekly-terraform-plan.sh)
- [semaphore-weekly-ansible-check.sh](scripts/semaphore-weekly-ansible-check.sh)

### Terraform weekly plan

This script:

- runs `terraform init`
- runs `terraform plan -detailed-exitcode`
- treats both “no changes” and “changes detected” as successful job outcomes

Recommended command in Semaphore:

```bash
cd /workspace/HomeLab && ./scripts/semaphore-weekly-terraform-plan.sh
```

### Ansible weekly check

This script:

- ensures the vault password file is available
- installs collections
- runs Ansible syntax check against `ansible/playbooks/check.yml`
- runs `ansible all -m ping`

Optional:

- if `SEMAPHORE_RUN_ANSIBLE_CHECK_MODE=true`, it also runs:
  - `ansible-playbook ansible/playbooks/check.yml --check --diff`

Recommended command in Semaphore:

```bash
cd /workspace/HomeLab && ./scripts/semaphore-weekly-ansible-check.sh
```

## First-Time Semaphore Setup

After the `Semaphore` stack is up:

1. Create the workspace path:

```bash
mkdir -p /mnt/appdata/docker_volumes/semaphore/workspace
```

2. Clone this repo into the mounted workspace on the LXC host:

```bash
cd /mnt/appdata/docker_volumes/semaphore/workspace
git clone https://github.com/wrightwells/HomeLab.git HomeLab
```

3. Create the Ansible vault password file for Semaphore:

```bash
mkdir -p /mnt/appdata/docker_volumes/semaphore/.config/ansible
printf '%s\n' 'REPLACE_WITH_YOUR_VAULT_PASSWORD' > /mnt/appdata/docker_volumes/semaphore/.config/ansible/homelab-vault-pass.txt
chmod 600 /mnt/appdata/docker_volumes/semaphore/.config/ansible/homelab-vault-pass.txt
```

4. In the Semaphore UI, create scheduled tasks for:

- weekly Terraform plan
- weekly Ansible check

These schedules are created in the Semaphore GUI, and the tasks should call the
repo scripts directly.

## Why This Shape

This repo keeps the existing HomeLab layout rather than importing a generic
starter tree. The main ideas borrowed from the starter are:

- scheduled wrapper scripts for Terraform and Ansible checks
- a dedicated Ansible dry-run entrypoint
- keeping Terraform apply manual rather than scheduled

## Notes

- The scripts assume the repo is available at `/workspace/HomeLab` inside the container
- The vault password file is expected at:
  - `/root/.config/ansible/homelab-vault-pass.txt`
- The Semaphore database now runs in the same compose bundle on PostgreSQL
- `stack.env` files do not expand other variables, so set:
  - `SEMAPHORE_DB_PASS`
  - `POSTGRES_PASSWORD`
  to the same real password value
- If you store the repo at a different path, update the Semaphore task commands accordingly
- If you want Semaphore to check for Ansible drift, enable:
  - `SEMAPHORE_RUN_ANSIBLE_CHECK_MODE=true`
  in the task environment
