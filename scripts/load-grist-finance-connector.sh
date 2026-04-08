#!/usr/bin/env bash
# load-grist-finance-connector.sh -- Build and load the private grist-finance-connector image.
#
# This script builds the image from the Dockerfile in the repo, copies it to the
# docker-apps LXC, and loads it into Docker's local image catalogue.
#
# Usage: ./scripts/load-grist-finance-connector.sh [LXC_IP]
# Default LXC_IP: 10.10.20.220

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_DIR="$ROOT_DIR/ansible/files/docker-images/lxc220-docker-apps/grist-finance-connector"
LXC_IP="${1:-10.10.20.220}"
IMAGE_NAME="grist-finance-connector"
IMAGE_TAG="0.1.0"
TAR_FILE="${IMAGE_NAME}_${IMAGE_TAG}.tar"

echo "=== Step 1: Building ${IMAGE_NAME}:${IMAGE_TAG} ==="
if command -v docker &>/dev/null; then
  docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" "$IMAGE_DIR"
else
  echo "Docker not found on this host. Building on docker-apps LXC (${LXC_IP})..."
  scp -o StrictHostKeyChecking=no -r "$IMAGE_DIR/"* "root@${LXC_IP}:/tmp/grist-connector-build/"
  ssh -o StrictHostKeyChecking=no "root@${LXC_IP}" "mkdir -p /tmp/grist-connector-build && docker build -t ${IMAGE_NAME}:${IMAGE_TAG} /tmp/grist-connector-build/"
fi

echo ""
echo "=== Step 2: Saving image as tar archive ==="
if command -v docker &>/dev/null; then
  docker save -o "$IMAGE_DIR/$TAR_FILE" "${IMAGE_NAME}:${IMAGE_TAG}"
  chmod 600 "$IMAGE_DIR/$TAR_FILE"
  echo "Saved: $IMAGE_DIR/$TAR_FILE"
else
  ssh -o StrictHostKeyChecking=no "root@${LXC_IP}" "docker save -o /tmp/${TAR_FILE} ${IMAGE_NAME}:${IMAGE_TAG}"
  scp -o StrictHostKeyChecking=no "root@${LXC_IP}:/tmp/${TAR_FILE}" "$IMAGE_DIR/$TAR_FILE"
  chmod 600 "$IMAGE_DIR/$TAR_FILE"
  echo "Saved: $IMAGE_DIR/$TAR_FILE"
fi

echo ""
echo "=== Step 3: Loading image into Docker on docker-apps (${LXC_IP}) ==="
if command -v docker &>/dev/null; then
  docker load -i "$IMAGE_DIR/$TAR_FILE"
else
  scp -o StrictHostKeyChecking=no "$IMAGE_DIR/$TAR_FILE" "root@${LXC_IP}:/tmp/${TAR_FILE}"
  ssh -o StrictHostKeyChecking=no "root@${LXC_IP}" "docker load -i /tmp/${TAR_FILE} && rm -f /tmp/${TAR_FILE}"
fi

echo ""
echo "=== Step 4: Verifying image ==="
if command -v docker &>/dev/null; then
  docker images | grep "${IMAGE_NAME}"
else
  ssh -o StrictHostKeyChecking=no "root@${LXC_IP}" "docker images | grep ${IMAGE_NAME}"
fi

echo ""
echo "=== Done ==="
echo "The grist-finance-connector image is now in Docker's local catalogue on docker-apps."
echo "To deploy, ensure it is enabled in build_inventory.yml and run the site playbook."
