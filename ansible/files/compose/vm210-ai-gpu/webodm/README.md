# WebODM on ai-gpu

This stack follows the upstream WebODM Docker layout with the NVIDIA GPU
processing-node overlay:

- `webodm/webodm_webapp` for the web app and worker
- `webodm/webodm_db` for PostgreSQL
- `redis:7.0.10` for the broker
- `webodm/nodeodx:gpu` for the default local GPU processing node

Persistent data lives under `/mnt/appdata/webodm`:

- `/mnt/appdata/webodm/db`
- `/mnt/appdata/webodm/media`
- `/mnt/appdata/webodm/node/data`
- `/mnt/appdata/webodm/node/tmp`
- `/mnt/appdata/webodm/secret_key`

Deploy from the repo root with:

```bash
./scripts/ansible-site.sh --limit ai_gpu
```

WebODM listens on `http://10.10.20.210:8000` by default.
