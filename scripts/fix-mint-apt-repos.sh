#!/usr/bin/env bash

set -euo pipefail

APPDATA_ROOT="${APPDATA_ROOT:-/mnt/appdata}"
MEDIA_ROOT="${MEDIA_ROOT:-/mnt/media_pool}"
APPDATA_TAG="${APPDATA_TAG:-homelab-appdata}"
MEDIA_TAG="${MEDIA_TAG:-homelab-media-pool}"
LOG_FILE="${LOG_FILE:-/tmp/fix-mint-apt-repos.log}"

if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

OFFICIAL_REPOS_FILE="/etc/apt/sources.list.d/official-package-repositories.list"
APT_SOURCE_CANDIDATES=(
  /etc/apt/sources.list
  /etc/apt/sources.list.d/*.list
  /etc/apt/sources.list.d/*.sources
)

if [ ! -f "$OFFICIAL_REPOS_FILE" ]; then
  echo "Could not find ${OFFICIAL_REPOS_FILE}" >&2
  exit 1
fi

exec > >(tee "$LOG_FILE") 2>&1

echo "Logging to ${LOG_FILE}"

echo "Ensuring shared virtiofs mounts exist and persist across reboot"
$SUDO mkdir -p "$APPDATA_ROOT" "$MEDIA_ROOT"
if ! grep -qE "^[^#]*[[:space:]]${APPDATA_ROOT}[[:space:]]+virtiofs[[:space:]]" /etc/fstab; then
  printf '%s %s virtiofs rw,relatime 0 0\n' "$APPDATA_TAG" "$APPDATA_ROOT" | $SUDO tee -a /etc/fstab >/dev/null
fi
if ! grep -qE "^[^#]*[[:space:]]${MEDIA_ROOT}[[:space:]]+virtiofs[[:space:]]" /etc/fstab; then
  printf '%s %s virtiofs rw,relatime 0 0\n' "$MEDIA_TAG" "$MEDIA_ROOT" | $SUDO tee -a /etc/fstab >/dev/null
fi

if ! mountpoint -q "$APPDATA_ROOT"; then
  $SUDO mount -t virtiofs "$APPDATA_TAG" "$APPDATA_ROOT" || true
fi
if ! mountpoint -q "$MEDIA_ROOT"; then
  $SUDO mount -t virtiofs "$MEDIA_TAG" "$MEDIA_ROOT" || true
fi

echo
echo "Basic system diagnostics:"
date || true
timedatectl status || true
ip -br addr || true
ip route || true
getent hosts archive.ubuntu.com || true
getent hosts security.ubuntu.com || true
getent hosts packages.linuxmint.com || true

echo "Detected Linux Mint / Ubuntu base:"
. /etc/os-release
printf '  ID=%s\n  VERSION=%s\n  UBUNTU_CODENAME=%s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}" "${UBUNTU_CODENAME:-unknown}"

echo "Disabling any install-media APT source in /etc/apt/sources.list"
if [ -f /etc/apt/sources.list ]; then
  $SUDO sed -i 's/^deb cdrom:/# deb cdrom:/g' /etc/apt/sources.list
fi

echo "Updating official Ubuntu repository entries to noble"
$SUDO sed -i \
  -e 's/\<focal\>/noble/g' \
  -e 's/\<jammy\>/noble/g' \
  -e 's/\<kinetic\>/noble/g' \
  -e 's/\<lunar\>/noble/g' \
  -e 's/\<mantic\>/noble/g' \
  -e 's/\<oracular\>/noble/g' \
  "$OFFICIAL_REPOS_FILE"

echo "Scanning all APT source files for stale Ubuntu codenames"
for source_file in "${APT_SOURCE_CANDIDATES[@]}"; do
  for resolved_file in $source_file; do
    [ -f "$resolved_file" ] || continue
    $SUDO sed -i \
      -e 's/\<focal\>/noble/g' \
      -e 's/\<jammy\>/noble/g' \
      -e 's/\<kinetic\>/noble/g' \
      -e 's/\<lunar\>/noble/g' \
      -e 's/\<mantic\>/noble/g' \
      -e 's/\<oracular\>/noble/g' \
      "$resolved_file"
  done
done

echo "Scanning Deb822 .sources files for stale Suites entries"
for resolved_file in /etc/apt/sources.list.d/*.sources; do
  [ -f "$resolved_file" ] || continue
  $SUDO sed -i \
    -e 's/\bzena-security\b/noble-security/g' \
    -e 's/\bzena-updates\b/noble-updates/g' \
    -e 's/\bzena-backports\b/noble-backports/g' \
    -e 's/\bzena\b/noble/g' \
    -e 's/\bjammy-security\b/noble-security/g' \
    -e 's/\bjammy-updates\b/noble-updates/g' \
    -e 's/\bjammy-backports\b/noble-backports/g' \
    -e 's/\bjammy\b/noble/g' \
    "$resolved_file"
done

echo
echo "Current official package repositories:"
cat "$OFFICIAL_REPOS_FILE"

echo
echo "All active deb sources:"
grep -R ^deb /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true

echo
echo "All active deb822 source files:"
grep -R ^Suites: /etc/apt/sources.list.d/*.sources 2>/dev/null || true

echo
echo "Cleaning stale APT metadata"
$SUDO apt-get clean || true
$SUDO rm -rf /var/lib/apt/lists/*

echo
echo "Running apt update"
if ! $SUDO apt-get update; then
  echo
  echo "Retrying apt update with --allow-releaseinfo-change"
  if ! $SUDO apt-get update --allow-releaseinfo-change; then
    echo
    echo "apt-get update still failed."
    echo "APT policy summary:"
    apt-cache policy || true
    echo
    echo "Quick HTTP checks:"
    curl -I --max-time 15 http://archive.ubuntu.com/ubuntu/dists/noble/Release || true
    curl -I --max-time 15 http://security.ubuntu.com/ubuntu/dists/noble-security/Release || true
    echo
    echo "Check all configured sources with:"
    echo "  grep -R ^deb /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null"
    echo "  grep -R ^Suites: /etc/apt/sources.list.d/*.sources 2>/dev/null"
    echo
    echo "If a third-party repo is still broken, disable its .list file under /etc/apt/sources.list.d/ and rerun this script."
    exit 1
  fi
fi

echo
echo "APT source repair complete."
echo "If you still hit package download issues later, review ${LOG_FILE}."
