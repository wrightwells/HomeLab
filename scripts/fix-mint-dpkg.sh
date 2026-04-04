#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="${LOG_FILE:-/tmp/fix-mint-dpkg.log}"
UPDATES_DIR="/var/lib/dpkg/updates"
UPDATES_BACKUP_DIR=""

if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

exec > >(tee "$LOG_FILE") 2>&1

echo "Logging to ${LOG_FILE}"
echo
echo "Basic package-manager diagnostics:"
date || true
uname -a || true
df -h / /var /tmp || true
ls -l /var/lib/dpkg/lock* /var/cache/apt/archives/lock 2>/dev/null || true

echo
echo "Pending dpkg audit before repair:"
$SUDO dpkg --audit || true

repair_dpkg_updates_queue() {
  if [ ! -d "$UPDATES_DIR" ]; then
    return 0
  fi

  UPDATES_BACKUP_DIR="/var/lib/dpkg/updates.homelab-backup-$(date +%Y%m%d%H%M%S)"
  echo
  echo "Backing up transient dpkg update records from ${UPDATES_DIR} to ${UPDATES_BACKUP_DIR}"
  $SUDO mkdir -p "$UPDATES_BACKUP_DIR"
  if find "$UPDATES_DIR" -maxdepth 1 -type f | grep -q .; then
    $SUDO find "$UPDATES_DIR" -maxdepth 1 -type f -print -exec mv {} "$UPDATES_BACKUP_DIR"/ \;
  else
    echo "No update records found to move."
  fi
}

echo
echo "Running dpkg --configure -a"
set +e
$SUDO dpkg --configure -a
DPKG_EXIT=$?
set -e

if [ "$DPKG_EXIT" -ne 0 ] && grep -q "parsing file '/var/lib/dpkg/updates/" "$LOG_FILE"; then
  echo
  echo "Detected corrupted transient dpkg update records."
  repair_dpkg_updates_queue
  echo
  echo "Retrying dpkg --configure -a after clearing the transient updates queue"
  set +e
  $SUDO dpkg --configure -a
  DPKG_EXIT=$?
  set -e
fi

if [ "$DPKG_EXIT" -eq 0 ]; then
  echo
  echo "dpkg --configure -a completed successfully."
  echo "Running apt-get install -f to confirm package consistency"
  $SUDO apt-get install -f -y
  echo
  echo "dpkg repair complete."
  echo "Log saved to ${LOG_FILE}"
  exit 0
fi

echo
echo "dpkg --configure -a failed with exit code ${DPKG_EXIT}"

echo
echo "dpkg audit after failure:"
$SUDO dpkg --audit || true

echo
echo "Recently unpacked or half-configured packages:"
awk '
  BEGIN { pkg = ""; status = "" }
  /^Package: / { pkg = $2 }
  /^Status: / {
    status = substr($0, 9)
    if (status ~ /half-installed|unpacked|half-configured|triggers-awaited|triggers-pending/) {
      print pkg ": " status
    }
  }
' /var/lib/dpkg/status 2>/dev/null || true

echo
echo "Recent dpkg log entries:"
tail -n 80 /var/log/dpkg.log 2>/dev/null || true

echo
echo "Recent apt term log entries:"
tail -n 80 /var/log/apt/term.log 2>/dev/null || true

echo
echo "Installed package state summary:"
set +e
dpkg -l | awk '$1 ~ /^(iF|iU|rc|un|pn|hi|tr)$/ { print }'
DPKG_LIST_EXIT=$?
set -e
if [ "$DPKG_LIST_EXIT" -ne 0 ] && [ -d "$UPDATES_DIR" ]; then
  echo "dpkg -l could not read package state cleanly; current transient updates directory listing:"
  ls -la "$UPDATES_DIR" || true
fi

echo
echo "Next checks:"
echo "  1. Read the first explicit error above from dpkg --configure -a."
echo "  2. If it mentions a missing file or maintainer script, inspect that package:"
echo "       dpkg -L <package-name>"
echo "       apt-cache policy <package-name>"
echo "  3. Share this log file:"
echo "       ${LOG_FILE}"
if [ -n "$UPDATES_BACKUP_DIR" ]; then
  echo "  4. Transient dpkg update records were backed up to:"
  echo "       ${UPDATES_BACKUP_DIR}"
fi

exit "$DPKG_EXIT"
