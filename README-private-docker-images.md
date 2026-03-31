# Private Docker Images

This repo reserves a place for released Docker image archives for private images
that are not pulled from a public registry.

Important:

- the repo should contain the folder structure and `README.md` files
- the actual image tar files are local artifacts and should be copied in after
  the HomeLab repo has been pulled
- the tar files are ignored by git and should not be committed

## Folder layout

Store private image artifacts under:

```text
ansible/files/docker-images/<bundle-name>/<stack-name>/
```

Example for the Grist finance connector:

```text
ansible/files/docker-images/lxc220-docker-apps/grist-finance-connector/
```

Each stack image folder should include a committed `README.md` describing:

- what image archive belongs in that folder
- the expected image name and tag
- any special release or verification steps

You can also keep additional reference files in the same folder, for example:

- sample documents
- import templates
- release notes
- stack-specific helper files

## Supported archive files

Ansible will automatically copy the whole folder into the deployed compose stack
directory. That means the `README.md`, any additional reference files, and any
image archives all move together as part of the install. It will then load any
of these file types it finds before `docker compose` starts:

- `*.tar`
- `*.tar.gz`
- `*.tgz`

The files are copied to:

```text
<docker_compose_root>/<stack-name>/docker-images/
```

The shared Docker deployment role then loads archives with:

```bash
docker load -i <docker_compose_root>/<stack-name>/docker-images/<archive>
```

## Example workflow

1. Pull or update the HomeLab repo.

2. Build and tag the image locally:

```bash
docker build -t grist-finance-connector:0.1.0 .
```

3. Save the image tar into the correct local folder in the checked-out repo:

```bash
docker save -o ansible/files/docker-images/lxc220-docker-apps/grist-finance-connector/grist-finance-connector_0.1.0.tar grist-finance-connector:0.1.0
```

4. Optional local verification:

```bash
docker load -i ansible/files/docker-images/lxc220-docker-apps/grist-finance-connector/grist-finance-connector_0.1.0.tar
docker images | grep grist-finance-connector
```

5. Deploy as normal:

```bash
ANSIBLE_VAULT_PASSWORD_FILE=~/.config/ansible/homelab-vault-pass.txt ansible-playbook ansible/playbooks/site.yml
```

During deployment, Ansible will:

1. copy the stack image folder, including `README.md` and any additional reference files, into the target compose directory
2. run `docker load -i ...`
3. start the compose stack

## Important rule

The image tag inside the tar archive must match the tag your compose stack
expects.

For `grist-finance-connector`, the compose file expects:

```text
grist-finance-connector:${IMAGE_TAG:-0.1.0}
```

So either:

- save an image tagged `grist-finance-connector:0.1.0`, or
- change `IMAGE_TAG` in that stack's `stack.env`

## Notes

- This is intended for private or locally built images.
- The repo should keep the folder and `README.md`, not the tarball itself.
- Additional non-archive reference files may be kept in the folder and will be
  copied to the target stack as part of deployment.
- Public images should usually stay in `docker-compose.yml` as normal `image:`
  references.
- If multiple archives are present in the stack folder, Ansible will load all
  of them.
