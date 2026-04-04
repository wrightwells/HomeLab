#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_ROOT="/mnt/appdata/homelab-control"
TARGET_BIN="${TARGET_ROOT}/bin"
TARGET_BOOTSTRAP_SCRIPT="${TARGET_BIN}/bootstrap-control-node.sh"
TARGET_APT_FIX_SCRIPT="${TARGET_BIN}/fix-mint-apt-repos.sh"
TARGET_DPKG_FIX_SCRIPT="${TARGET_BIN}/fix-mint-dpkg.sh"
TARGET_UPDATE_SCRIPT="${TARGET_BIN}/update-control-node.sh"
TARGET_USER_BOOTSTRAP_SCRIPT="${TARGET_BIN}/bootstrap-user-control-node.sh"
TARGET_GITHUB_KEY="${TARGET_BIN}/github-deploy-key"
TARGET_GITHUB_PUB_KEY="${TARGET_GITHUB_KEY}.pub"
TARGET_NOTE="${TARGET_ROOT}/README-bootstrap.txt"

mkdir -p "$TARGET_BIN"
install -m 0755 "${ROOT_DIR}/scripts/bootstrap-control-node.sh" "$TARGET_BOOTSTRAP_SCRIPT"
install -m 0755 "${ROOT_DIR}/scripts/fix-mint-apt-repos.sh" "$TARGET_APT_FIX_SCRIPT"
install -m 0755 "${ROOT_DIR}/scripts/fix-mint-dpkg.sh" "$TARGET_DPKG_FIX_SCRIPT"
install -m 0755 "${ROOT_DIR}/scripts/update-control-node.sh" "$TARGET_UPDATE_SCRIPT"
install -m 0755 "${ROOT_DIR}/scripts/bootstrap-user-control-node.sh" "$TARGET_USER_BOOTSTRAP_SCRIPT"
install -m 0600 "/root/.ssh/id_ed25519" "$TARGET_GITHUB_KEY"
install -m 0644 "/root/.ssh/id_ed25519.pub" "$TARGET_GITHUB_PUB_KEY"

cat >"$TARGET_NOTE" <<'EOF'
Shared HomeLab control-node bootstrap

Run this from Linux Mint or infra-250 after /mnt/appdata is mounted:

  /mnt/appdata/homelab-control/bin/bootstrap-control-node.sh

If Linux Mint apt sources are broken with archive.ubuntu.com 404 errors, run:

  /mnt/appdata/homelab-control/bin/fix-mint-apt-repos.sh

If dpkg was interrupted and asks for "sudo dpkg --configure -a", run:

  /mnt/appdata/homelab-control/bin/fix-mint-dpkg.sh

To pull the latest HomeLab repo updates into shared appdata and run Ansible:

  /mnt/appdata/homelab-control/bin/update-control-node.sh

To build the control node the same way Mint and the future infra server will
run it, cloning the repo into ~/HomeLab and then running Ansible:

  /mnt/appdata/homelab-control/bin/bootstrap-user-control-node.sh

That bootstrap also installs the shared GitHub deploy key from:

  /mnt/appdata/homelab-control/bin/github-deploy-key

The bootstrap script installs git and ansible, clones or updates the HomeLab
repo under /mnt/appdata/homelab-control/HomeLab, and installs the Ansible
collections.

The Mint APT repair helper also writes persistent virtiofs mount entries to
/etc/fstab for /mnt/appdata and /mnt/media_pool.
EOF

echo "Published control-node bootstrap to ${TARGET_BOOTSTRAP_SCRIPT}"
echo "Published Linux Mint APT repair helper to ${TARGET_APT_FIX_SCRIPT}"
echo "Published Linux Mint dpkg repair helper to ${TARGET_DPKG_FIX_SCRIPT}"
echo "Published control-node update helper to ${TARGET_UPDATE_SCRIPT}"
echo "Published user-home control-node bootstrap to ${TARGET_USER_BOOTSTRAP_SCRIPT}"
echo "Published GitHub deploy key to ${TARGET_GITHUB_KEY}"
