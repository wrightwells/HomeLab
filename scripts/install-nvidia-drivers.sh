#!/usr/bin/env bash
# install-nvidia-drivers.sh -- Install NVIDIA driver and Container Toolkit on the AI GPU VM.
#
# This script runs inside the AI GPU VM (vm210-ai-gpu) after GPU passthrough
# has been configured and the VM has been started.
#
# Usage (from Proxmox host):
#   ssh ansible@10.10.20.210 'bash -s' < scripts/install-nvidia-drivers.sh

set -euo pipefail

echo "=== Installing NVIDIA drivers and Container Toolkit ==="

# ---------------------------------------------------------------------------
# Install kernel headers (required for driver build)
# ---------------------------------------------------------------------------
sudo apt-get update -qq
sudo apt-get install -y linux-headers-"$(uname -r)"

# ---------------------------------------------------------------------------
# Add NVIDIA Container Toolkit repository
# ---------------------------------------------------------------------------
echo "=== Adding NVIDIA Container Toolkit repo ==="
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
echo 'deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH) /' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# ---------------------------------------------------------------------------
# Install NVIDIA driver and Container Toolkit
# ---------------------------------------------------------------------------
echo "=== Installing NVIDIA driver 570 and Container Toolkit ==="
sudo apt-get update -qq
sudo apt-get install -y nvidia-driver-570 nvidia-container-toolkit

# ---------------------------------------------------------------------------
# Configure Docker runtime for NVIDIA
# ---------------------------------------------------------------------------
echo "=== Configuring Docker runtime ==="
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
echo ""
echo "=== Verifying GPU access ==="
nvidia-smi

echo ""
echo "=== Testing GPU in Docker ==="
sudo docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi 2>&1 | head -15

echo ""
echo "=== NVIDIA setup complete ==="
echo "Reboot the VM to ensure the driver is loaded, then run the Ansible site playbook."
