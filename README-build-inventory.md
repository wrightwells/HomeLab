# Build Inventory Guide

This guide explains how to use the new build-inventory structure to keep the
full homelab defined in the repo while deploying only the parts you want.

The source of truth is
[build_inventory.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/build_inventory.yml).

## What The Structure Does

The build inventory controls four things:

- which guests are included in the active build
- which Docker bundles are enabled on each guest
- which logical mounts a guest or bundle expects
- which storage stores are available on the current hardware

This means the repo can always keep the full target design, but a smaller host
can still use the same repo without deleting modules, roles, or compose files.

## How To Think About It

There are three layers:

1. Repo definition

- all guests stay defined in Terraform and Ansible
- all compose bundles stay defined in the repo

2. Build selection

- `guests.*.enabled` says whether a VM or LXC is included
- `services.<host>.<bundle>.enabled` says whether a Docker bundle is deployed

3. Storage intent

- `storage.stores` describes available backing stores such as `host_os`,
  `appdata`, `media`, and `ai_fast`
- `storage.mounts` describes logical paths such as `/mnt/appdata` and
  `/mnt/media_pool`
- a logical mount can prefer a dedicated store but fall back to `host_os`

## How It Is Used By The Repo

Terraform:

- always keeps `vm100_pfsense` enabled
- reads the build inventory
- creates only the guests marked `enabled: true`
- renders the Ansible inventory with only the enabled guests

Ansible:

- reads the same build inventory file
- runs roles only for hosts present in the generated inventory
- deploys only the Docker bundles marked `enabled: true`

## Normal Workflow

1. Edit
   [build_inventory.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/build_inventory.yml)
2. Set which guests you want in this build
3. Set which bundles you want on each enabled guest
4. Describe the storage stores and logical mount fallbacks for the actual host
5. Run Terraform so it renders the matching Ansible inventory
6. Run Ansible against that rendered inventory

## Example: Host Disk And Media Disk Only

Assume this machine has:

- one host disk for Proxmox, guest root disks, and appdata fallback
- one media disk for `/mnt/media_pool`
- no dedicated appdata disk
- no AI fast disk

And you only want:

- `vm100_pfsense`
- `lxc066_docker_arr` for the ARR stack
- `lxc230_docker_media` for Plex

### Guest Selection

In `build_inventory.yml`, keep these enabled:

- `vm100_pfsense`
- `lxc066_docker_arr`
- `lxc230_docker_media`

Disable these:

- `vm210_ai_gpu`
- `lxc200_docker_services`
- `lxc220_docker_apps`
- `lxc240_docker_external`
- `lxc250_infra`

### Service Selection

For `lxc066_docker_arr`, enable only:

- `arr-stack`

Disable:

- `filebrowser`
- `jellyseerr`
- `aurral`

For `lxc230_docker_media`, enable only:

- `plex`

Disable:

- `jellyfin`
- `jellyswarrm`

### Storage Selection

For this reduced host:

- `host_os.enabled: true`
- `media.enabled: true`
- `appdata.enabled: false`
- `ai_fast.enabled: false`

Keep the logical mount `appdata` enabled, but point it to fallback storage on
the host disk:

- `appdata.enabled: true`
- `appdata.preferred_store: appdata`
- `appdata.fallback_store: host_os`

Keep the logical media mount enabled:

- `media.enabled: true`
- `media.preferred_store: media`

Disable the AI mounts:

- `ai_models.enabled: false`
- `ai_cache.enabled: false`

### Why This Works

This gives you:

- the same `/mnt/appdata` path the roles and compose bundles already expect
- the same `/mnt/media_pool` path for downloads and Plex media
- no AI guest or AI services
- no extra internal app, external app, or infra guests

So the repo structure stays stable, while the active build becomes a small
media-focused deployment.

## Example YAML Shape

This is the kind of change you would make for that example:

```yaml
build_inventory:
  guests:
    vm100_pfsense:
      enabled: true
    vm210_ai_gpu:
      enabled: false
    lxc066_docker_arr:
      enabled: true
    lxc200_docker_services:
      enabled: false
    lxc220_docker_apps:
      enabled: false
    lxc230_docker_media:
      enabled: true
    lxc240_docker_external:
      enabled: false
    lxc250_infra:
      enabled: false

  services:
    lxc066_docker_arr:
      filebrowser:
        enabled: false
      jellyseerr:
        enabled: false
      aurral:
        enabled: false
      arr-stack:
        enabled: true

    lxc230_docker_media:
      plex:
        enabled: true
      jellyfin:
        enabled: false
      jellyswarrm:
        enabled: false

  storage:
    stores:
      host_os:
        enabled: true
      appdata:
        enabled: false
      media:
        enabled: true
      ai_fast:
        enabled: false

    mounts:
      appdata:
        enabled: true
        preferred_store: appdata
        fallback_store: host_os
      media:
        enabled: true
        preferred_store: media
      ai_models:
        enabled: false
      ai_cache:
        enabled: false
```

## Practical Notes

- `vm100_pfsense` should stay enabled
- disabling a guest removes it from the generated Ansible inventory
- disabling a bundle stops Ansible from deploying that compose stack
- guest root disks are still controlled by Terraform storage variables such as
  `vm_storage` and `lxc_storage`
- host disk partitioning and filesystem creation are still manual unless you
  add more automation later

## Good Rule Of Thumb

Use the build inventory to answer two questions:

- what do I want to run in this build?
- what storage does this machine actually have today?

If those two answers are captured correctly in
[build_inventory.yml](/home/ww/HomeLab/HomeLab/ansible/inventories/production/build_inventory.yml),
the rest of the repo can stay unchanged.
