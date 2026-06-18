# HomeLab

Infrastructure-as-code repository for a Proxmox homelab.

## Before You Run

Create an Ansible vault password file on the machine that will run the playbooks.
This password is used to decrypt any `stack.env.vault` files during deployment and
write them to the target hosts as plain `stack.env` files.

Example setup:

```bash
mkdir -p ~/.config/ansible
printf '%s\n' 'REPLACE_WITH_YOUR_VAULT_PASSWORD' > ~/.config/ansible/homelab-vault-pass.txt
chmod 600 ~/.config/ansible/homelab-vault-pass.txt
```

Run Ansible with:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=~/.config/ansible/homelab-vault-pass.txt ansible-playbook ansible/playbooks/site.yml
```

Notes:

- Do not commit the vault password file.
- If you prefer an interactive prompt, use `ansible-playbook --ask-vault-pass`.
- Terraform should be run first so it can render the Ansible inventory from the current build inventory.
- The helper scripts under `scripts/` are intended to be run directly as `./scripts/<name>.sh`. If a clone on another client loses executable permissions, restore them with `chmod +x scripts/*.sh`.

## Build Inventory

The repo now keeps the full homelab definition in place while letting you build
only the pieces you want.

Use [build_inventory.yml](ansible/inventories/production/build_inventory.yml)
to control:

- which guests are included in the generated build
- which Docker bundles are enabled on each guest
- which logical storage mounts are expected
- which backing stores are enabled for the current hardware layout

Example use cases:

- full build with every guest and service enabled, using the `balanced_96gb` profile
- lightweight build with only `vm100_pfsense`, `lxc230_docker_media`, and a few core services, using the `balanced_32gb` profile
- reduced storage build where `/mnt/appdata` still exists but falls back to `host_os` instead of a separate appdata disk

Use [site_config.yml](ansible/inventories/production/site_config.yml) to control:

- whether the build is UK or France
- the second IP octet, for example `10.10.x.x` for UK or `10.20.x.x` for France
- the domain suffix such as `uk.wrightwells.com` or `fr.wrightwells.com`
- VLAN-backed subnet ranges used by Terraform and generated inventory

## Hosts

- VM100 pfSense
- VM150 Mint desktop
- VM210 AI-GPU
- VM300 OpenClaw
- LXC066 docker-arr
- LXC200 docker-services
- LXC220 docker-apps
- LXC230 docker-media
- LXC240 docker-external
- LXC250 infra

All of these remain defined in the repo. Inclusion in a given build is driven by
the build inventory file rather than by deleting repo configuration.

## Storage model

- NVMe 500GB: /mnt/ai_models, /mnt/ai_cache, Frigate recordings, LLM cache
- SSD 500GB: Proxmox OS, Terraform repo, LXC rootfs, VM root disks, Docker runtime
- RAID1 2x4TB: /mnt/appdata for config, databases, Docker volumes, Syncthing critical data
- Media pool 4x12TB: /mnt/media_pool via mergerfs

## Rebuild an LXC

This repo separates guest creation from guest configuration:

- Terraform and Proxmox create the LXC shell
- Ansible configures the workload inside it
- Semaphore on `infra-01` is intended to run the steady-state Ansible jobs
- the Proxmox host is the bootstrap fallback when `infra-01` or Semaphore is not ready yet

For a normal worker LXC, the rebuild flow is:

1. Recreate or reapply the container with Terraform:

```bash
./scripts/terraform-apply.sh production
```

2. Verify the recreated LXC is reachable from the control node.
3. Run the relevant Ansible limit from Semaphore, or from the Proxmox host if Semaphore is not available yet.
4. Let Ansible restore the host role:
   packages, Docker, config files, env files, and compose stacks.

Typical limits are:

- `docker_services`
- `docker_apps`
- `docker_media`
- `docker_arr`
- `docker_external`
- `infra`
- a single host such as `infra-01`

If you need to run the rebuild from the Proxmox host instead of Semaphore:

```bash
./scripts/ensure-proxmox-host-ansible.sh
./scripts/run-ansible-on-proxmox-host.sh --limit infra
```

### `infra-01` bootstrap exception

`infra-01` is special because it also hosts Semaphore and acts as a shared
control node.

That means its rebuild flow is:

1. Terraform recreates CT `250`.
2. Proxmox must provide the shared `/mnt/appdata` mount to the container.
3. The shared control workspace must exist under:
   `/mnt/appdata/homelab-control`
4. Rebuild `infra-01` from the Proxmox host first.
5. Once Semaphore is back, use it to manage the other worker LXCs again.

In other words:

- Terraform creates the guest
- Proxmox/shared storage provides the persistent control assets
- Ansible rebuilds the role
- Semaphore resumes as the preferred runner after `infra-01` is healthy

## Hardware

- CPU: 8 cores / 16 threads
- RAM: 128 GB
- See [docs/terraform-corrections.md](docs/terraform-corrections.md) for profile adjustments made to match actual hardware.

Note:

- The current repo does not format or assemble those host disks automatically.
- Terraform consumes existing Proxmox datastores and existing host mount paths.
- The build inventory describes which logical stores are enabled and whether a mount should prefer a dedicated disk or fall back to `host_os`.
- See the storage guide for the full process.

## Guides

- [Bootstrap Guide](README-bootstrap.md)
- [Networking Guide](README-networking.md)
- [Storage Guide](README-storage.md)
- [Sizing Guide](README-sizing.md)
- [Build Inventory Guide](README-build-inventory.md)
- [Private Docker Images](README-private-docker-images.md)
- [Build Inventory](ansible/inventories/production/build_inventory.yml)
- [Site Config](ansible/inventories/production/site_config.yml)
- [Session Prompt](README-session-prompt.md)
- [Service Catalog](README-services.md)
- [Home Assistant Voice Stack](docs/home-assistant-voice-stack.md)
- [Home Assistant Ollama Setup](docs/home-assistant-ollama.md)
- [Add Docker Component](README-add-docker-component.md)
- [Semaphore Guide](README-semaphore.md)
- [Stack Env Vault Script](README-stack-env-vaults.md)
- [Continue Config Example](continue/config.yaml.example)
  This is a local client-side example and is not part of the automated deployment.



## TODO
ITEM 1:
Update my Frigate Docker Compose and Frigate config so Frigate uses the Nvidia/TensorRT image instead of the CPU detector.

Current Frigate compose service is:

```yaml
services:
  frigate:
    image: ghcr.io/blakeblackshear/frigate:stable
    container_name: frigate
    restart: unless-stopped
    privileged: true
    shm_size: "512mb"
    network_mode: host
    environment:
      - TZ=Europe/London
      - NVIDIA_VISIBLE_DEVICES=all
      - LIBVA_DRIVER_NAME=nvidia
    volumes:
      - /mnt/appdata/configs/frigate:/config
      - /mnt/ai_cache/frigate:/media/frigate
      - /etc/localtime:/etc/localtime:ro
    tmpfs:
      - /tmp/cache:size=1073741824
    gpus: all
```

Required changes:

1. Change the Frigate image from:

```yaml
image: ghcr.io/blakeblackshear/frigate:stable
```

to:

```yaml
image: ghcr.io/blakeblackshear/frigate:stable-tensorrt
```

2. Increase shared memory from:

```yaml
shm_size: "512mb"
```

to:

```yaml
shm_size: "1024mb"
```

3. Keep GPU passthrough enabled with:

```yaml
gpus: all
```

4. Keep these existing volume mappings exactly as they are:

```yaml
- /mnt/appdata/configs/frigate:/config
- /mnt/ai_cache/frigate:/media/frigate
- /etc/localtime:/etc/localtime:ro
```

5. Add this Nvidia capability environment variable:

```yaml
- NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
```

6. Keep the existing environment variables:

```yaml
- TZ=Europe/London
- NVIDIA_VISIBLE_DEVICES=all
- LIBVA_DRIVER_NAME=nvidia
```

7. Update Frigate’s `config.yml` to add an Nvidia ONNX detector section near the top of the file, without removing my existing cameras, MQTT, face recognition, LPR, or recording settings.

Add this:

```yaml
detectors:
  onnx:
    type: onnx

model:
  model_type: yolo-generic
  width: 320
  height: 320
  input_tensor: nchw
  input_dtype: float
  path: /config/model_cache/yolo.onnx
  labelmap_path: /labelmap/coco-80.txt
```

8. Create the model cache directory on the host if it does not already exist:

```bash
mkdir -p /mnt/appdata/configs/frigate/model_cache
```

9. Add comments or a README note explaining that the required object-detection model file must be placed here on the host:

```text
/mnt/appdata/configs/frigate/model_cache/yolo.onnx
```

Inside the container this becomes:

```text
/config/model_cache/yolo.onnx
```

10. The model needed is a YOLO ONNX model compatible with Frigate’s ONNX detector, exported at 320x320 input size and saved as:

```text
/config/model_cache/yolo.onnx
```

Use a YOLO v7/v9-style COCO object detection ONNX model, 320x320, with the COCO label map:

```text
/labelmap/coco-80.txt
```

11. Do not download a random incompatible model. Add a clear TODO/comment saying the user must provide or export a compatible YOLO ONNX model to:

```text
/mnt/appdata/configs/frigate/model_cache/yolo.onnx
```

12. After editing, provide the commands to redeploy and verify:

```bash
docker compose pull
docker compose up -d
docker exec -it frigate nvidia-smi
docker logs -f frigate | grep -i -E 'detector|onnx|cuda|tensorrt|cpu|error'
```

13. The expected outcome is that this warning should disappear:

```text
CPU detectors are not recommended and should only be used for testing or for trial purposes.
```

14. Do not change my camera RTSP URLs, MQTT credentials, recording paths, face recognition settings, LPR settings, or network mode.
----------------------------------------------------------
ITEM 2:
 1. Frigate should have a config folder /mnt/appdata/config/frgate   but is not being created or populated
----------------------------------------------------------
ITEM 3:
1. Check all docker compose files , all container configuration should be in volumes /mnt/appdata/docker_volumes/[conatiner name]
examples that are incorrect
   1. aurral 
      - aurral-data:/app/backend/data
   2. immich
      - immich-db:/var/lib/postgresql/data
   3. owncloud
      - owncloud-db:/var/lib/mysql
      - owncloud-data:/mnt/data
   4. paperless-ngx
      - paperless-db:/var/lib/postgresql/data
   5. blinko
      - blinko-db:/var/lib/postgresql/data
   6. eurgo
      - erugo-data:/var/www/html/storage
   and any others
-------------------------------------------------------------
ITEM 4:
