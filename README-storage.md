# Storage Guide

This guide explains which disks are managed manually on the Proxmox host, which
disks Terraform creates for guests, and what happens when you rerun the build
later.

Use this guide only for the Proxmox host storage step during the first install.
Your main runbook remains [README-bootstrap.md](README-bootstrap.md).
Once host storage is prepared, return to the bootstrap guide and continue there.

## Summary

Current repo behavior:

- Proxmox host installation disk is manual.
- Proxmox host data-disk layout is manual.
- Terraform creates VM and LXC guest disks on Proxmox datastores that already
  exist.
- Terraform does not partition, format, mirror, or build MergerFS on the
  Proxmox host.
- Ansible deploys software into guests, but it does not currently prepare host
  block devices either.
- The build inventory now describes the intended logical storage layout and
  which stores are enabled for the current build.

That means the repo assumes the host storage foundations already exist before
you run the infrastructure build.

## Disk Layers

Think of the storage in four layers.

The file
[build_inventory.yml](ansible/inventories/production/build_inventory.yml)
describes the logical storage intent:

- storage stores such as `host_os`, `appdata`, `media`, and `ai_fast`
- logical mounts such as `appdata`, `media`, `ai_models`, and `ai_cache`
- preferred backing stores and fallbacks
- which guests and services require which mounts

That means a lighter host layout can still be described cleanly without
rewriting the repo.

### 1. Proxmox host OS disk

This is your host SSD where you install Proxmox itself.

Expected use:

- Proxmox VE
- local repo checkout
- Terraform state in the repo
- small Proxmox local storage items if you choose

This disk is installed and formatted by the Proxmox installer, not by this
repo.

## 2. Proxmox datastores used by Terraform

Terraform uses these logical Proxmox storage targets:

- `vm_storage`
- `lxc_storage`
- `cloudinit_storage`

These are names of Proxmox datastores, not raw disks.

Examples:

- `local-lvm`
- `local`
- `nvme-vm`
- `raid1-appdata`

Terraform creates guest disks on those datastores, but it does not create the
datastores themselves.

## 3. Proxmox host paths bind-mounted into LXCs

Several LXC modules mount host paths directly into the container, such as:

- `/mnt/appdata`
- `/mnt/media_pool`

Example:

- [main.tf](terraform/modules/lxc230-docker-media/main.tf)
- [main.tf](terraform/modules/lxc066-docker-arr/main.tf)

These `mount_point` blocks assume those paths already exist on the Proxmox
host. Terraform does not create the underlying filesystem for them.

## 4. Paths inside the AI VM

The AI VM uses paths like:

- `/mnt/ai_models`
- `/mnt/ai_cache`
- `/mnt/appdata`
- `/mnt/appdata/code`

Those are inside the guest operating system.

Important:

- the current `vm210-ai-gpu` module creates one VM disk of `128G`
- it does not currently add separate VM disks for NVMe, appdata, or media
- unless you later mount extra storage inside the VM, those paths all live on
  the VM root filesystem

See:

- [main.tf](terraform/modules/vm210-ai-gpu/main.tf)

So today, the storage intent in the Docker Compose files is ahead of the actual
VM disk model. The AI VM still needs a second pass if you want true separation
between fast model storage and persistent appdata storage inside that VM.

## 5. Paths inside the Linux Mint workstation VM

The Linux Mint desktop VM on VMID `150` (`vm050-mint`) models host-style extra storage with
additional virtual disks intended for:

- `/mnt/ai_models`
- `/mnt/ai_cache`
- `/mnt/media_pool`

The Terraform module attaches separate NVMe-style and media-style disks, and
the Ansible role mounts them inside the guest. This gives the workstation the
same logical path shape as the host while still using VM-backed storage.

## Your Chosen Layout

Based on our discussion, the intended storage model is:

- Host SSD: Proxmox OS
- Host NVMe: fast AI storage, kept on the Proxmox host
- Mirrored application disk set: ZFS mirror mounted for `/mnt/appdata`
- Media disks with MergerFS: `/mnt/media_pool`
- Shared directory layout created during bootstrap under `/mnt/appdata` and `/mnt/media_pool`

That is a good design, but only part of it is currently automated.

It is now also documented in the build inventory so you can express variants
such as:

- host OS disk plus media disk only
- host OS disk plus appdata mirror, without AI fast storage
- full host OS, appdata, media, and AI fast storage

For example, if a reduced build has no dedicated appdata disk yet:

- keep the logical mount `/mnt/appdata`
- mark its preferred store as `appdata`
- let it fall back to `host_os`

That keeps guest and Docker path assumptions stable while the physical hardware
is smaller.

For media, your requirement is:

- initial build may have only one media disk
- later builds may add a second or third media disk
- this should be parameter-driven

Yes, that can be parameter-driven. The clean pattern is:

- define a list of media disks by stable device ID
- format only disks that are not already prepared
- mount each disk to a predictable branch path such as `/mnt/media_disk01`
- build or update the MergerFS pool from the current list of mounted media disks

With that model:

- first install can work with one media disk
- later updates can add more media disks
- reruns should preserve existing formatted disks if the automation checks first

## What Terraform Does Today

Terraform currently does these storage-related actions:

- creates the pfSense VM root disk on `vm_storage`
- creates the Linux Mint workstation root disk on `vm_storage`
- creates Linux Mint workstation data disks on `vm050_mint_nvme_storage` and `vm050_mint_media_storage`
- creates the AI VM root disk on `vm_storage`
- creates each LXC root filesystem on `lxc_storage`
- creates cloud-init data on `cloudinit_storage`
- bind-mounts `/mnt/appdata` and `/mnt/media_pool` into selected LXCs

Terraform does not currently:

- partition host disks
- create filesystems on host disks
- create mdadm RAID1 arrays
- create MergerFS pools
- mount host disks in `/etc/fstab`
- add extra virtual disks to the AI VM for `/mnt/ai_models` or `/mnt/appdata`
- format guest data disks inside the AI VM

For the Linux Mint desktop VM on VMID `150` (`vm050-mint`), the repo does currently:

- attach extra VM-backed disks for NVMe-style and media-style storage
- format those disks inside the guest if needed
- mount `/mnt/ai_models`, bind-mount `/mnt/ai_cache`, and mount `/mnt/media_pool`

## What Happens On Rebuild Or Reapply

### Proxmox host disks

The extra host disks are not touched by Terraform today.

So if you manually build:

- the NVMe mount
- the RAID1 appdata mount
- the MergerFS media pool

then rerunning Terraform or Ansible will not reformat them.

They stay as they are unless you manually change them outside the repo.

### VM and LXC root disks

Terraform manages the guest disks attached to the VMs and LXCs it creates.

Normal `terraform apply` behavior:

- does not reformat an existing guest disk on every run
- reconciles config drift where the provider supports it
- leaves existing guest disks in place unless a change forces replacement or
  you explicitly destroy the resource

Destructive cases would be things like:

- destroying a VM or LXC
- changing immutable arguments that force recreation
- manually deleting the guest outside Terraform

### LXC bind mounts

The `mount_point` declarations will continue to expect the same host paths.

If `/mnt/appdata` or `/mnt/media_pool` already exist and remain mounted on the
host, repeated applies should just keep using them.

They are not reformatted by Terraform.

## What Is Missing For Full Automation

If you want the repo to fully implement your intended layout, there are two
major gaps.

### Gap 1. Host storage bootstrap

You still need a host-side process to:

- identify the correct disks
- partition them
- create filesystems
- create the ZFS mirror for appdata
- create the MergerFS pool
- mount them at the expected paths

That should be done very carefully, because it is destructive the first time
and dangerous to rerun incorrectly.

### Gap 2. AI VM data-disk layout

Right now the AI VM only has one root disk.

If you want the VM to really separate:

- `/mnt/ai_models/ollama` on fast storage
- `/mnt/ai_cache/frigate` on fast storage
- `/mnt/appdata/*` on mirrored storage

then we should add extra virtual disks to `vm210-ai-gpu`, mount them in the
guest, and only then point Docker volumes at those mount points.

## Recommended Process Right Now

For the first build:

1. Install Proxmox on the host SSD.
2. Build the host storage layout for:
   - NVMe
   - ZFS mirror appdata
   - MergerFS media
3. Mount those on the Proxmox host at:
   - `/mnt/appdata`
   - `/mnt/media_pool`
   - any additional host paths you choose, such as `/mnt/ai_models` and `/mnt/ai_cache`
4. Create the Proxmox datastores you want Terraform to use.
5. Run Terraform to create the guests.
6. Run Ansible to configure software in the guests.
7. In a later pass, extend the AI VM with extra disks if you want true storage
   separation inside the guest.

For the second or third update:

- rerunning Terraform should not reformat your manual host storage
- rerunning Ansible should not reformat your manual host storage
- but guest replacement can still be destructive if you intentionally recreate
  a VM or LXC

## Safer Future Automation Pattern

If we automate host storage later, the safest pattern is:

1. detect disks by stable ID, not `/dev/sdX`
2. check whether ZFS/filesystems already exist
3. only create them when they do not exist
4. mount by UUID
5. keep destructive creation behind an explicit flag such as
   `storage_bootstrap_force = true`

That way a rerun acts like a check-and-reconcile pass rather than a wipe.

## Automation Plan For Your Chosen Design

The host-storage bootstrap can be automated, but it should not live inside the
main Terraform apply path. It is better as a separate, explicit host-prep step.

Implemented direction in this repo:

1. A dedicated Ansible playbook for the Proxmox host:
   - [proxmox-storage.yml](ansible/playbooks/proxmox-storage.yml)
2. Inventory-backed storage variables for the Proxmox host:
   - [proxmox.yml](ansible/inventories/production/group_vars/proxmox.yml)
3. A dedicated role that prepares:
   - NVMe `ext4`
   - appdata ZFS mirror
   - media-disk `xfs`
   - MergerFS pool

Recommended implementation pattern:

1. Run the Proxmox host storage playbook explicitly before Terraform.
2. Variables for:
   - NVMe disk ID
   - ZFS mirror disk IDs
   - media disk ID list
   - desired mount points
3. Initial creation only when the storage is absent.
4. Non-destructive reruns that:
   - verify the ZFS pool exists
   - verify the NVMe filesystem exists
   - verify each media disk filesystem exists
   - update the MergerFS branch list when a new media disk is added

This gives you:

- destructive formatting on first install only
- parameter-driven media expansion later
- safe second and third runs

## Running The Storage Bootstrap

1. Update the placeholder disk IDs in:
   - [proxmox.yml](ansible/inventories/production/group_vars/proxmox.yml)
2. For the first run only, set:

```yaml
proxmox_storage_allow_destructive_create: true
```

3. Run:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventories/production/hosts.ini playbooks/proxmox-storage.yml
```

4. After the initial storage build succeeds, set:

```yaml
proxmox_storage_allow_destructive_create: false
```

That keeps later runs in a safer reconciliation mode.

The storage bootstrap also creates the shared host directories used by the lab:

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
- `/mnt/appdata/docker_volumes`
- `/mnt/appdata/configs`

Some application-specific subdirectories may still be created later by Docker
or individual Ansible roles, but this shared base layout is now created by the
Proxmox host storage bootstrap itself.

## Remaining Questions Before We Automate It

- Which filesystem do you want on the host NVMe: `ext4` or `xfs`?
- Which filesystem do you want on each MergerFS member disk: `ext4` or `xfs`?
- What mount points do you want for the NVMe-backed host paths:
  - `/mnt/ai_models`
  - `/mnt/ai_cache`
  - anything else
- Do you want the ZFS pool mounted directly at `/mnt/appdata`, or mounted at a
  pool name and then bind-mounted to `/mnt/appdata`?
- Do you want me to implement this as:
  - a shell bootstrap script under `scripts/`
  - an Ansible playbook for the Proxmox host
  - or both
