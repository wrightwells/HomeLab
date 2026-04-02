#!/usr/bin/env bash

set -euo pipefail

apply_pct() {
  local vmid="$1"
  shift

  if ! pct status "$vmid" >/dev/null 2>&1; then
    echo "Skipping CT $vmid because it does not exist yet." >&2
    return 0
  fi

  echo "Applying post-create settings to CT $vmid"
  pct set "$vmid" "$@"
}

apply_pct 166 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata --mp1 /mnt/media_pool,mp=/mnt/media_pool
apply_pct 200 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata
apply_pct 220 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata
apply_pct 230 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata --mp1 /mnt/media_pool,mp=/mnt/media_pool
apply_pct 240 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata
apply_pct 250 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata

cat <<'EOF'
Done.

If any containers were already running, restart them to pick up new mount points
and feature flags:
  pct reboot 166 200 220 230 240 250
EOF
