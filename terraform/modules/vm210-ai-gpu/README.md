# vm210-ai-gpu

Linux VM for AI and Docker workloads cloned from a prepared Proxmox template.
Next step is usually PCIe GPU passthrough.

This module is ready for a later passthrough update once the Proxmox host is
built and you know the real GPU PCI address. Record that value in the root
variable `vm210_gpu_pci_address`, for example `0000:02:00`, then update the
VM resource with the exact `bpg/proxmox` PCI device block supported by the
installed provider version.
