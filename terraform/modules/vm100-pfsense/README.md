# vm100-pfsense

Starter pfSense VM placeholder.
Use this as the shell VM and attach a pfSense ISO manually or extend later.
The default bridge layout is:

- `vmbr1` for WAN on `nic1`
- `vmbr2` for the LAN/trusted trunk on `nic2`
- `vmbr3` for the DMZ or untrusted segment
