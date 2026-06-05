# vm100-pfsense

Starter pfSense VM for the bootstrap phase.
It expects the pfSense installer image to already exist in Proxmox storage and
imports it as a bootable installer disk automatically.
The default bridge layout is:

- `vmbr1` for WAN on `nic1`
- `vmbr2` for the LAN/trusted trunk on `nic2`
- `vmbr3` for the DMZ or untrusted segment
