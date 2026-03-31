# grist-finance-connector private image

Place released image archives for this stack in this folder after pulling the
HomeLab repo locally.

Do not commit the tar file back into git. This folder's `README.md` stays in
the repo, but the archive itself is a local deployment artifact.

Expected image reference:

```text
grist-finance-connector:0.1.0
```

Expected archive example:

```text
grist-finance-connector_0.1.0.tar
```

Typical workflow:

```bash
git pull
docker build -t grist-finance-connector:0.1.0 .
docker save -o ansible/files/docker-images/lxc220-docker-apps/grist-finance-connector/grist-finance-connector_0.1.0.tar grist-finance-connector:0.1.0
docker load -i ansible/files/docker-images/lxc220-docker-apps/grist-finance-connector/grist-finance-connector_0.1.0.tar
docker images | grep grist-finance-connector
```

At deploy time, Ansible copies this folder into the stack compose directory and
loads any `.tar`, `.tar.gz`, or `.tgz` archives it finds.
