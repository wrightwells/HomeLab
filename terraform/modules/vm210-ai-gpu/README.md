# vm210-ai-gpu

Linux VM for AI and Docker workloads cloned from a prepared Proxmox template.
Next step is usually PCIe GPU passthrough.

This module now supports repeatable Proxmox PCI-mapping-based passthrough once
the host is built and you know the real GPU identity.

Set these root variables after `./scripts/setup-gpu-passthrough.sh` reports the
correct values:

- `vm210_gpu_pci_address`, for example `0000:06:00`
- `vm210_gpu_device_id`, for example `10de:2504`
- `vm210_gpu_iommu_group`, for example `29`
- `vm210_gpu_subsystem_id`, for example `1462:397d`

Then re-run the production Terraform apply. The module will:

- switch the VM to `q35`
- create a Proxmox PCI hardware mapping
- attach the mapped GPU to `hostpci0`
- seed the guest `ansible` account with both the SSH key and bootstrap password

That keeps future rebuilds repeatable and avoids one-off `qm set --hostpci0`
drift on the live host.
