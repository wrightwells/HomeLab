# Syncthing Media Folder Live Fix

Use this when `syncthing` on `lxc200-docker-services` can write to existing media folders but fails on a newly synced top-level folder under `/mnt/media_pool`.

Typical error in Syncthing logs:

```text
Failed to create folder marker ... mkdir /media_pool/<FOLDER>/.stfolder: permission denied
Failed initial scan ... folder marker missing
```

## Why this happens

`lxc200-docker-services` is an unprivileged LXC.

- Guest `uid=1000 gid=1000`
- Host-mapped IDs: `101000:101000`

If a new folder on the Proxmox host is created with plain host ownership like `1000:1000` or `root:root`, Syncthing inside the LXC will not be able to create `.stfolder` or write data into it.

## Manual live fix

Run these commands on the Proxmox host.

Replace `ROMS` with the new top-level folder name.

```bash
chown 101000:101000 /mnt/media_pool/ROMS
mkdir -p /mnt/media_pool/ROMS/.stfolder
chown 101000:101000 /mnt/media_pool/ROMS/.stfolder
```

## Verify from the host

```bash
ls -ldn /mnt/media_pool/ROMS /mnt/media_pool/ROMS/.stfolder
```

Expected owner/group:

```text
101000 101000
```

## Verify from inside `lxc200`

```bash
pct exec 200 -- sh -lc 'ls -ldn /mnt/media_pool/ROMS /mnt/media_pool/ROMS/.stfolder'
```

Expected owner/group inside the container:

```text
1000 1000
```

Optional write test as the Syncthing container user:

```bash
pct exec 200 -- sh -lc 'docker exec -u 1000 syncthing sh -lc "touch /media_pool/ROMS/.perm-test && rm -f /media_pool/ROMS/.perm-test && echo ok"'
```

## If Syncthing still shows the old error

Restart the stack on `lxc200`:

```bash
pct exec 200 -- sh -lc 'cd /opt/containers/syncthing && docker compose restart syncthing'
```

Then recheck logs:

```bash
pct exec 200 -- sh -lc 'docker logs --tail 80 syncthing 2>&1'
```

You want to see the folder complete its initial scan and stop reporting `folder marker missing`.

## Permanent repo fix

If this folder should always exist, add it to:

[`ansible/roles/proxmox_host_storage/defaults/main.yml`](/home/ww/HomeLab/ansible/roles/proxmox_host_storage/defaults/main.yml)

under `proxmox_media_pool_directories`, then apply the Proxmox storage play so future rebuilds recreate it with the correct mapped ownership.
