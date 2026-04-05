#!/usr/bin/env bash

set -euo pipefail

REBOOT_CTS=()
REBOOT_VMS=()
PVE_NODE="$(hostname)"
MINT_VMID=150
APPDATA_DIRID="homelab-appdata"
MEDIA_DIRID="homelab-media-pool"

has_virtiofsd() {
  command -v virtiofsd >/dev/null 2>&1 \
    || [ -x /usr/libexec/virtiofsd ] \
    || [ -x /usr/lib/qemu/virtiofsd ] \
    || [ -x /usr/lib/virtiofsd ]
}

ensure_dir_mapping() {
  local dirid="$1"
  local path="$2"

  if pvesh get "/cluster/mapping/dir/${dirid}" >/dev/null 2>&1; then
    echo "Directory mapping ${dirid} already exists"
    return 0
  fi

  echo "Creating directory mapping ${dirid} -> ${path}"
  pvesh create /cluster/mapping/dir --id "$dirid" --map "node=${PVE_NODE},path=${path}"
}

configure_mint_vm() {
  if ! qm status "$MINT_VMID" >/dev/null 2>&1; then
    echo "Skipping VM ${MINT_VMID} because it does not exist yet." >&2
    return 0
  fi

  if ! has_virtiofsd; then
    echo "Skipping VM ${MINT_VMID} virtiofs setup because virtiofsd is not installed on the Proxmox host." >&2
    echo "Install it first with: apt install virtiofsd" >&2
    return 0
  fi

  ensure_dir_mapping "$APPDATA_DIRID" /mnt/appdata
  ensure_dir_mapping "$MEDIA_DIRID" /mnt/media_pool

  echo "Attaching virtiofs shares to VM ${MINT_VMID}"
  qm set "$MINT_VMID" --virtiofs0 "dirid=${APPDATA_DIRID},cache=always"
  qm set "$MINT_VMID" --virtiofs1 "dirid=${MEDIA_DIRID},cache=always"
  REBOOT_VMS+=("$MINT_VMID")
}

apply_pct() {
  local vmid="$1"
  shift

  if ! pct status "$vmid" >/dev/null 2>&1; then
    echo "Skipping CT $vmid because it does not exist yet." >&2
    return 0
  fi

  echo "Applying post-create settings to CT $vmid"
  pct set "$vmid" "$@"
  REBOOT_CTS+=("$vmid")
}

apply_pct 166 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata --mp1 /mnt/media_pool,mp=/mnt/media_pool
apply_pct 200 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata
apply_pct 220 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata
apply_pct 230 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata --mp1 /mnt/media_pool,mp=/mnt/media_pool
apply_pct 240 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata
apply_pct 250 --features nesting=1,keyctl=1 --mp0 /mnt/appdata,mp=/mnt/appdata

configure_mint_vm

if [ "${#REBOOT_CTS[@]}" -gt 0 ]; then
  echo "Rebooting updated containers to pick up new mount points and feature flags"
  for vmid in "${REBOOT_CTS[@]}"; do
    pct reboot "$vmid"
  done
fi

if [ "${#REBOOT_VMS[@]}" -gt 0 ]; then
  echo "Rebooting updated VMs to pick up new virtiofs devices"
  for vmid in "${REBOOT_VMS[@]}"; do
    if qm status "$vmid" | grep -q "status: running"; then
      qm reboot "$vmid"
    else
      echo "VM ${vmid} is not running; start it manually to use the new virtiofs shares."
    fi
  done
fi

echo "Done."
