#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${1:-/opt/HomeLab}"
FORCE="${FORCE:-0}"

log() {
  printf '%s\n' "$*"
}

ensure_dir() {
  mkdir -p "$1"
}

write_file() {
  local path="$1"
  ensure_dir "$(dirname "$path")"

  if [[ -f "$path" && "$FORCE" != "1" ]]; then
    log "Skipping existing file: $path"
    return 0
  fi

  cat > "$path"
  log "Wrote: $path"
}

main() {
  log "Populating working starter scaffold in: $ROOT_DIR"

  ensure_dir "$ROOT_DIR"
  cd "$ROOT_DIR"

  # Top-level layout
  ensure_dir ansible/inventories/production/group_vars
  ensure_dir ansible/inventories/production/host_vars
  ensure_dir ansible/playbooks
  ensure_dir ansible/roles/common/tasks
  ensure_dir ansible/roles/common/handlers
  ensure_dir ansible/roles/common/templates
  ensure_dir ansible/roles/docker_host/tasks
  ensure_dir ansible/roles/docker_host/templates
  ensure_dir ansible/roles/proxmox_host/tasks
  ensure_dir ansible/roles/proxmox_host/templates
  ensure_dir docker/compose/ai
  ensure_dir docker/compose/automation
  ensure_dir docker/compose/media
  ensure_dir layout/docs
  ensure_dir scripts
  ensure_dir terraform/modules/lxc_container
  ensure_dir terraform/modules/vm_qemu
  ensure_dir terraform/templates
  ensure_dir terraform/generated

  write_file README.md <<'EOF'
# HomeLab

Infrastructure-as-code starter repository for a Proxmox-based homelab.

## Repository layout

- `terraform/` - Proxmox VM/LXC definitions and generated Ansible inventory
- `ansible/` - host configuration, Docker host setup, common roles
- `docker/compose/` - application stacks deployed onto selected hosts
- `scripts/` - helper scripts for validation and local workflows
- `layout/` - notes, diagrams, and planning documentation

## Typical workflow

1. Edit `terraform/terraform.tfvars` with your Proxmox details and desired VM/LXC definitions.
2. Run Terraform to create or update infrastructure.
3. Terraform writes a generated inventory file to `ansible/inventories/production/hosts.yml`.
4. Run Ansible against that inventory.
5. Deploy application stacks on the Docker hosts.

## First run

```bash
cd /opt/HomeLab/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply

cd /opt/HomeLab
ansible-inventory -i ansible/inventories/production/hosts.yml --graph
ansible-playbook -i ansible/inventories/production/hosts.yml ansible/playbooks/site.yml
```

## Notes

- The generated inventory file is managed by Terraform.
- Keep secrets out of Git. Use environment variables, Ansible Vault, or a secret manager.
- This is a starter scaffold and should be adapted to your exact storage, network, and VM/LXC templates.
EOF

  write_file .gitignore <<'EOF'
# Terraform
**/.terraform/*
*.tfstate
*.tfstate.*
crash.log
crash.*.log
.terraform.lock.hcl

# Secrets and overrides
*.auto.tfvars
terraform.tfvars
*.vault.yml
*.vault.yaml
.env
.env.*

# Ansible
*.retry
ansible/inventories/production/hosts.yml

# Editors / OS
.vscode/
.idea/
*.swp
.DS_Store
EOF

  write_file layout/docs/notes.md <<'EOF'
# HomeLab Notes

Use this folder for:
- hardware inventory
- IP plan
- VLAN plan
- storage layout
- backup and recovery notes
EOF

  write_file scripts/tf-apply.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/HomeLab/terraform
terraform init
terraform apply "$@"
EOF

  write_file scripts/ansible-site.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/HomeLab
ansible-playbook -i ansible/inventories/production/hosts.yml ansible/playbooks/site.yml "$@"
EOF

  chmod +x scripts/tf-apply.sh scripts/ansible-site.sh

  write_file terraform/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
    }
  }
}
EOF

  write_file terraform/providers.tf <<'EOF'
provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  insecure  = var.pm_tls_insecure
  ssh {
    agent = true
  }
}
EOF

  write_file terraform/variables.tf <<'EOF'
variable "pm_api_url" {
  description = "Proxmox API URL, for example https://pve.example.com:8006/api2/json"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID, for example terraform@pve!provider"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Set true when using self-signed Proxmox TLS certificates"
  type        = bool
  default     = true
}

variable "target_node" {
  description = "Default Proxmox node to place workloads on"
  type        = string
}

variable "default_gateway" {
  description = "Default IPv4 gateway"
  type        = string
}

variable "default_bridge" {
  description = "Default Proxmox bridge"
  type        = string
  default     = "vmbr0"
}

variable "default_storage" {
  description = "Default Proxmox storage target"
  type        = string
  default     = "local-lvm"
}

variable "lxc_definitions" {
  description = "Map of LXC containers to create"
  type = map(object({
    vmid        = number
    hostname    = string
    description = optional(string, "")
    tags        = optional(list(string), [])
    ostemplate  = string
    cores       = number
    memory      = number
    swap        = optional(number, 512)
    rootfs_size = number
    ip_address  = string
    gateway     = optional(string)
    bridge      = optional(string)
    vlan_id     = optional(number)
    onboot      = optional(bool, true)
    unprivileged = optional(bool, true)
    start       = optional(bool, true)
    ansible_groups = optional(list(string), [])
  }))
  default = {}
}

variable "vm_definitions" {
  description = "Map of QEMU VMs to create"
  type = map(object({
    vmid          = number
    name          = string
    description   = optional(string, "")
    tags          = optional(list(string), [])
    clone         = optional(string)
    iso           = optional(string)
    cores         = number
    sockets       = optional(number, 1)
    memory        = number
    disk_size_gb  = number
    ip_address    = string
    gateway       = optional(string)
    bridge        = optional(string)
    vlan_id       = optional(number)
    onboot        = optional(bool, true)
    start_on_boot = optional(bool, true)
    agent         = optional(bool, true)
    ansible_groups = optional(list(string), [])
  }))
  default = {}
}
EOF

  write_file terraform/main.tf <<'EOF'
locals {
  lxc_inventory = {
    for name, cfg in var.lxc_definitions : name => {
      hostname = cfg.hostname
      ansible_host = split("/", cfg.ip_address)[0]
      ansible_user = "root"
      node         = var.target_node
      type         = "lxc"
      groups       = cfg.ansible_groups
    }
  }

  vm_inventory = {
    for name, cfg in var.vm_definitions : name => {
      hostname = cfg.name
      ansible_host = split("/", cfg.ip_address)[0]
      ansible_user = "root"
      node         = var.target_node
      type         = "vm"
      groups       = cfg.ansible_groups
    }
  }

  inventory_hosts = merge(local.lxc_inventory, local.vm_inventory)

  inventory_groups = {
    all = {
      vars = {
        ansible_python_interpreter = "/usr/bin/python3"
      }
      hosts = local.inventory_hosts
    }
  }
}

module "lxc" {
  source   = "./modules/lxc_container"
  for_each = var.lxc_definitions

  target_node  = var.target_node
  default_bridge = var.default_bridge
  default_gateway = var.default_gateway
  default_storage = var.default_storage

  config = each.value
}

module "vm" {
  source   = "./modules/vm_qemu"
  for_each = var.vm_definitions

  target_node  = var.target_node
  default_bridge = var.default_bridge
  default_gateway = var.default_gateway
  default_storage = var.default_storage

  config = each.value
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventories/production/hosts.yml"
  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    inventory_groups = local.inventory_groups
  })
}

output "generated_inventory" {
  value = local_file.ansible_inventory.filename
}
EOF

  write_file terraform/terraform.tfvars.example <<'EOF'
pm_api_url          = "https://pve.example.com:8006/api2/json"
pm_api_token_id     = "terraform@pve!provider"
pm_api_token_secret = "replace-me"
pm_tls_insecure     = true

target_node     = "pve"
default_gateway = "10.10.10.1"
default_bridge  = "vmbr0"
default_storage = "local-lvm"

lxc_definitions = {
  docker101 = {
    vmid           = 101
    hostname       = "docker101"
    description    = "Primary Docker LXC"
    tags           = ["docker", "lxc"]
    ostemplate     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    cores          = 4
    memory         = 8192
    swap           = 512
    rootfs_size    = 32
    ip_address     = "10.10.66.101/24"
    gateway        = "10.10.66.1"
    bridge         = "vmbr0"
    onboot         = true
    unprivileged   = true
    start          = true
    ansible_groups = ["docker_hosts", "media"]
  }
}

vm_definitions = {
  ai201 = {
    vmid           = 201
    name           = "ai201"
    description    = "AI and GPU VM"
    tags           = ["ai", "vm"]
    clone          = "ubuntu-2404-cloudinit-template"
    cores          = 8
    sockets        = 1
    memory         = 16384
    disk_size_gb   = 128
    ip_address     = "10.10.66.201/24"
    gateway        = "10.10.66.1"
    bridge         = "vmbr0"
    onboot         = true
    start_on_boot  = true
    agent          = true
    ansible_groups = ["vm_hosts", "ai"]
  }
}
EOF

  write_file terraform/templates/ansible_inventory.tftpl <<'EOF'
all:
  vars:
%{ for k, v in inventory_groups.all.vars ~}
    ${k}: ${yamlencode(v)}
%{ endfor ~}
  hosts:
%{ for host_key, host in inventory_groups.all.hosts ~}
    ${host_key}:
      hostname: ${yamlencode(host.hostname)}
      ansible_host: ${yamlencode(host.ansible_host)}
      ansible_user: ${yamlencode(host.ansible_user)}
      node: ${yamlencode(host.node)}
      type: ${yamlencode(host.type)}
%{ if length(host.groups) > 0 ~}
      host_groups: ${yamlencode(host.groups)}
%{ endif ~}
%{ endfor ~}
  children:
    docker_hosts:
      hosts:
%{ for host_key, host in inventory_groups.all.hosts ~}
%{ if contains(host.groups, "docker_hosts") ~}
        ${host_key}: {}
%{ endif ~}
%{ endfor ~}
    vm_hosts:
      hosts:
%{ for host_key, host in inventory_groups.all.hosts ~}
%{ if contains(host.groups, "vm_hosts") ~}
        ${host_key}: {}
%{ endif ~}
%{ endfor ~}
    ai:
      hosts:
%{ for host_key, host in inventory_groups.all.hosts ~}
%{ if contains(host.groups, "ai") ~}
        ${host_key}: {}
%{ endif ~}
%{ endfor ~}
    media:
      hosts:
%{ for host_key, host in inventory_groups.all.hosts ~}
%{ if contains(host.groups, "media") ~}
        ${host_key}: {}
%{ endif ~}
%{ endfor ~}
EOF

  write_file terraform/modules/lxc_container/variables.tf <<'EOF'
variable "target_node" {
  type = string
}

variable "default_bridge" {
  type = string
}

variable "default_gateway" {
  type = string
}

variable "default_storage" {
  type = string
}

variable "config" {
  type = object({
    vmid         = number
    hostname     = string
    description  = optional(string, "")
    tags         = optional(list(string), [])
    ostemplate   = string
    cores        = number
    memory       = number
    swap         = optional(number, 512)
    rootfs_size  = number
    ip_address   = string
    gateway      = optional(string)
    bridge       = optional(string)
    vlan_id      = optional(number)
    onboot       = optional(bool, true)
    unprivileged = optional(bool, true)
    start        = optional(bool, true)
    ansible_groups = optional(list(string), [])
  })
}
EOF

  write_file terraform/modules/lxc_container/main.tf <<'EOF'
resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.target_node
  vm_id        = var.config.vmid
  description  = var.config.description
  tags         = var.config.tags
  unprivileged = var.config.unprivileged
  started      = var.config.start
  on_boot      = var.config.onboot

  initialization {
    hostname = var.config.hostname

    ip_config {
      ipv4 {
        address = var.config.ip_address
        gateway = coalesce(var.config.gateway, var.default_gateway)
      }
    }
  }

  cpu {
    cores = var.config.cores
  }

  memory {
    dedicated = var.config.memory
    swap      = var.config.swap
  }

  disk {
    datastore_id = var.default_storage
    size         = var.config.rootfs_size
  }

  network_interface {
    name   = "eth0"
    bridge = coalesce(var.config.bridge, var.default_bridge)
    vlan_id = try(var.config.vlan_id, null)
  }

  operating_system {
    template_file_id = var.config.ostemplate
    type             = "debian"
  }
}
EOF

  write_file terraform/modules/vm_qemu/variables.tf <<'EOF'
variable "target_node" {
  type = string
}

variable "default_bridge" {
  type = string
}

variable "default_gateway" {
  type = string
}

variable "default_storage" {
  type = string
}

variable "config" {
  type = object({
    vmid          = number
    name          = string
    description   = optional(string, "")
    tags          = optional(list(string), [])
    clone         = optional(string)
    iso           = optional(string)
    cores         = number
    sockets       = optional(number, 1)
    memory        = number
    disk_size_gb  = number
    ip_address    = string
    gateway       = optional(string)
    bridge        = optional(string)
    vlan_id       = optional(number)
    onboot        = optional(bool, true)
    start_on_boot = optional(bool, true)
    agent         = optional(bool, true)
    ansible_groups = optional(list(string), [])
  })
}
EOF

  write_file terraform/modules/vm_qemu/main.tf <<'EOF'
resource "proxmox_virtual_environment_vm" "this" {
  node_name   = var.target_node
  vm_id       = var.config.vmid
  name        = var.config.name
  description = var.config.description
  tags        = var.config.tags
  on_boot     = var.config.onboot
  started     = var.config.start_on_boot

  agent {
    enabled = var.config.agent
  }

  cpu {
    cores   = var.config.cores
    sockets = var.config.sockets
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.config.memory
  }

  network_device {
    bridge  = coalesce(var.config.bridge, var.default_bridge)
    model   = "virtio"
    vlan_id = try(var.config.vlan_id, null)
  }

  disk {
    datastore_id = var.default_storage
    interface    = "scsi0"
    size         = var.config.disk_size_gb
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  dynamic "clone" {
    for_each = try(var.config.clone, null) != null ? [var.config.clone] : []
    content {
      vm_id = 0
    }
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.config.ip_address
        gateway = coalesce(var.config.gateway, var.default_gateway)
      }
    }
  }
}
EOF

  write_file ansible/ansible.cfg <<'EOF'
[defaults]
inventory = ./inventories/production/hosts.yml
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
interpreter_python = auto_silent
roles_path = ./roles
EOF

  write_file ansible/inventories/production/group_vars/all.yml <<'EOF'
---
lab_domain: home.arpa
timezone: Europe/London
common_packages:
  - curl
  - git
  - htop
  - vim
EOF

  write_file ansible/playbooks/site.yml <<'EOF'
---
- name: Baseline all hosts
  hosts: all
  become: true
  roles:
    - common

- name: Configure Docker hosts
  hosts: docker_hosts
  become: true
  roles:
    - docker_host

- name: Configure Proxmox hosts
  hosts: proxmox_hosts
  become: true
  roles:
    - proxmox_host
EOF

  write_file ansible/roles/common/tasks/main.yml <<'EOF'
---
- name: Set timezone
  community.general.timezone:
    name: "{{ timezone }}"

- name: Install common packages
  ansible.builtin.package:
    name: "{{ common_packages }}"
    state: present
EOF

  write_file ansible/roles/common/handlers/main.yml <<'EOF'
---
# Add handlers here as the role grows.
EOF

  write_file ansible/roles/docker_host/tasks/main.yml <<'EOF'
---
- name: Install Docker dependencies
  ansible.builtin.package:
    name:
      - ca-certificates
      - curl
      - gnupg
    state: present

- name: Ensure Docker compose root exists
  ansible.builtin.file:
    path: /opt/stacks
    state: directory
    mode: "0755"
EOF

  write_file ansible/roles/proxmox_host/tasks/main.yml <<'EOF'
---
- name: Placeholder Proxmox host role
  ansible.builtin.debug:
    msg: "Add Proxmox host-specific tasks here"
EOF

  write_file docker/compose/media/navidrome-compose.yml <<'EOF'
version: "3.9"

services:
  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    restart: unless-stopped
    ports:
      - "4533:4533"
    environment:
      ND_SCANINTERVAL: 1h
      ND_LOGLEVEL: info
      ND_SESSIONTIMEOUT: 24h
      ND_BASEURL: ""
    volumes:
      - /opt/stacks/navidrome/data:/data
      - /media_data/music:/music:ro
EOF

  write_file docker/compose/automation/n8n-compose.yml <<'EOF'
version: "3.9"

services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      TZ: Europe/London
      N8N_HOST: n8n.home.arpa
      N8N_PORT: 5678
      N8N_PROTOCOL: http
    volumes:
      - /opt/stacks/n8n/data:/home/node/.n8n
EOF

  write_file docker/compose/ai/open-webui-compose.yml <<'EOF'
version: "3.9"

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    ports:
      - "3000:8080"
    volumes:
      - /opt/stacks/open-webui:/app/backend/data
EOF

  write_file scripts/validate-structure.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

base="/opt/HomeLab"

required=(
  "$base/terraform/main.tf"
  "$base/terraform/templates/ansible_inventory.tftpl"
  "$base/ansible/playbooks/site.yml"
  "$base/ansible/roles/common/tasks/main.yml"
  "$base/docker/compose/media/navidrome-compose.yml"
)

failed=0
for item in "${required[@]}"; do
  if [[ -e "$item" ]]; then
    printf '[OK] %s\n' "$item"
  else
    printf '[MISSING] %s\n' "$item"
    failed=1
  fi
done

exit "$failed"
EOF

  chmod +x scripts/validate-structure.sh

  log "Done."
  log "Next steps:"
  log "  1. cp $ROOT_DIR/terraform/terraform.tfvars.example $ROOT_DIR/terraform/terraform.tfvars"
  log "  2. Edit terraform.tfvars"
  log "  3. cd $ROOT_DIR/terraform && terraform init && terraform apply"
  log "  4. cd $ROOT_DIR && ansible-playbook -i ansible/inventories/production/hosts.yml ansible/playbooks/site.yml"
}

main "$@"
