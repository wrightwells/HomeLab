#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/HomeLab"

if [[ ! -d "$BASE" ]]; then
  echo "ERROR: $BASE does not exist"
  exit 1
fi

echo "Populating working starter scaffold in: $BASE"

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------
mkdir -p "$BASE/terraform/modules"
mkdir -p "$BASE/terraform/environments/production"
mkdir -p "$BASE/terraform/templates"

mkdir -p "$BASE/ansible/inventories/production/group_vars"
mkdir -p "$BASE/ansible/inventories/production/host_vars"
mkdir -p "$BASE/ansible/playbooks"
mkdir -p "$BASE/ansible/roles"
mkdir -p "$BASE/ansible/templates"
mkdir -p "$BASE/ansible/files/compose"

mkdir -p "$BASE/scripts"
mkdir -p "$BASE/docs"

write_file() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  cat > "$file"
}

make_role_tree() {
  local role="$1"
  mkdir -p "$BASE/ansible/roles/$role"/{tasks,handlers,defaults,vars,meta,templates,files}
}

make_module_tree() {
  local module="$1"
  mkdir -p "$BASE/terraform/modules/$module"
}

# -----------------------------------------------------------------------------
# Terraform root
# -----------------------------------------------------------------------------
write_file "$BASE/terraform/providers.tf" <<'EOF2'
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.62"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  insecure  = true
}
EOF2

write_file "$BASE/terraform/variables.tf" <<'EOF2'
variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "littledown"
}

variable "vm_storage" {
  description = "Storage for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "lxc_storage" {
  description = "Storage for LXC rootfs"
  type        = string
  default     = "local-lvm"
}

variable "cloudinit_storage" {
  description = "Storage for cloud-init"
  type        = string
  default     = "local-lvm"
}

variable "vm_bridge" {
  description = "Bridge name"
  type        = string
  default     = "vmbr0"
}

variable "vm_vlan" {
  description = "Optional VLAN tag"
  type        = number
  default     = null
}

variable "ssh_public_key" {
  description = "SSH public key for guests"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ansible_user" {
  description = "Ansible SSH username"
  type        = string
  default     = "ansible"
}

variable "debian_lxc_template" {
  description = "Proxmox LXC template file id"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}
EOF2

write_file "$BASE/terraform/main.tf" <<'EOF2'
locals {
  inventory_hosts = {
    vm100_pfsense = {
      name   = "pfsense"
      type   = "vm"
      vmid   = 100
      ip     = "dhcp"
      groups = ["firewall"]
      user   = "admin"
    }

    vm210_ai_gpu = {
      name   = "ai-gpu"
      type   = "vm"
      vmid   = 210
      ip     = "10.10.66.210"
      groups = ["ai_gpu", "docker_hosts"]
      user   = var.ansible_user
    }

    lxc066_docker_arr = {
      name   = "docker-arr"
      type   = "lxc"
      vmid   = 66
      ip     = "10.10.66.66"
      groups = ["docker_arr", "docker_hosts"]
      user   = "root"
    }

    lxc200_docker_services = {
      name   = "docker-services"
      type   = "lxc"
      vmid   = 200
      ip     = "10.10.66.200"
      groups = ["docker_services", "docker_hosts"]
      user   = "root"
    }

    lxc220_docker_apps = {
      name   = "docker-apps"
      type   = "lxc"
      vmid   = 220
      ip     = "10.10.66.220"
      groups = ["docker_apps", "docker_hosts"]
      user   = "root"
    }

    lxc230_docker_media = {
      name   = "docker-media"
      type   = "lxc"
      vmid   = 230
      ip     = "10.10.66.230"
      groups = ["docker_media", "docker_hosts"]
      user   = "root"
    }

    lxc240_docker_external = {
      name   = "docker-external"
      type   = "lxc"
      vmid   = 240
      ip     = "10.10.66.240"
      groups = ["docker_external", "docker_hosts"]
      user   = "root"
    }

    lxc250_infra = {
      name   = "infra"
      type   = "lxc"
      vmid   = 250
      ip     = "10.10.66.250"
      groups = ["infra", "docker_hosts"]
      user   = "root"
    }
  }
}

module "vm100_pfsense" {
  source       = "./modules/vm100-pfsense"
  proxmox_node = var.proxmox_node
  vm_storage   = var.vm_storage
  vm_bridge    = var.vm_bridge
  vm_vlan      = var.vm_vlan
}

module "vm210_ai_gpu" {
  source            = "./modules/vm210-ai-gpu"
  proxmox_node      = var.proxmox_node
  vm_storage        = var.vm_storage
  cloudinit_storage = var.cloudinit_storage
  vm_bridge         = var.vm_bridge
  vm_vlan           = var.vm_vlan
  ssh_public_key    = var.ssh_public_key
  ansible_user      = var.ansible_user
}

module "lxc066_docker_arr" {
  source              = "./modules/lxc066-docker-arr"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  vm_bridge           = var.vm_bridge
  vm_vlan             = var.vm_vlan
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc200_docker_services" {
  source              = "./modules/lxc200-docker-services"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  vm_bridge           = var.vm_bridge
  vm_vlan             = var.vm_vlan
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc220_docker_apps" {
  source              = "./modules/lxc220-docker-apps"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  vm_bridge           = var.vm_bridge
  vm_vlan             = var.vm_vlan
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc230_docker_media" {
  source              = "./modules/lxc230-docker-media"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  vm_bridge           = var.vm_bridge
  vm_vlan             = var.vm_vlan
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc240_docker_external" {
  source              = "./modules/lxc240-docker-external"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  vm_bridge           = var.vm_bridge
  vm_vlan             = var.vm_vlan
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

module "lxc250_infra" {
  source              = "./modules/lxc250-infra"
  proxmox_node        = var.proxmox_node
  lxc_storage         = var.lxc_storage
  vm_bridge           = var.vm_bridge
  vm_vlan             = var.vm_vlan
  ssh_public_key      = var.ssh_public_key
  debian_lxc_template = var.debian_lxc_template
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventories/production/hosts.yml"
  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    hosts = local.inventory_hosts
  })
}
EOF2

write_file "$BASE/terraform/outputs.tf" <<'EOF2'
output "ansible_inventory_file" {
  value = local_file.ansible_inventory.filename
}

output "vm100_pfsense_id" {
  value = module.vm100_pfsense.vm_id
}

output "vm210_ai_gpu_id" {
  value = module.vm210_ai_gpu.vm_id
}

output "lxc066_docker_arr_id" {
  value = module.lxc066_docker_arr.vm_id
}

output "lxc200_docker_services_id" {
  value = module.lxc200_docker_services.vm_id
}

output "lxc220_docker_apps_id" {
  value = module.lxc220_docker_apps.vm_id
}

output "lxc230_docker_media_id" {
  value = module.lxc230_docker_media.vm_id
}

output "lxc240_docker_external_id" {
  value = module.lxc240_docker_external.vm_id
}

output "lxc250_infra_id" {
  value = module.lxc250_infra.vm_id
}
EOF2

write_file "$BASE/terraform/terraform.tfvars.example" <<'EOF2'
pm_api_url          = "https://10.10.66.2:8006/api2/json"
pm_api_token_id     = "terraform@pve!provider"
pm_api_token_secret = "REPLACE_ME"

proxmox_node         = "littledown"
vm_storage           = "local-lvm"
lxc_storage          = "local-lvm"
cloudinit_storage    = "local-lvm"
vm_bridge            = "vmbr0"
vm_vlan              = 66
debian_lxc_template  = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"

ansible_user   = "ansible"
ssh_public_key = "ssh-ed25519 AAAA_REPLACE_ME"
EOF2

write_file "$BASE/terraform/templates/ansible_inventory.tftpl" <<'EOF2'
all:
  children:
    firewall:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "firewall") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}

    ai_gpu:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "ai_gpu") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}

    docker_arr:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "docker_arr") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}

    docker_services:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "docker_services") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}

    docker_apps:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "docker_apps") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}

    docker_media:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "docker_media") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}

    docker_external:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "docker_external") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}

    infra:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "infra") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}

    docker_hosts:
      hosts:
%{ for _, host in hosts ~}
%{ if contains(host.groups, "docker_hosts") ~}
        ${host.name}:
          ansible_host: ${host.ip}
          ansible_user: ${host.user}
          vmid: ${host.vmid}
          guest_type: ${host.type}
%{ endif ~}
%{ endfor ~}
EOF2

write_file "$BASE/terraform/environments/production/main.tf" <<'EOF2'
module "homelab" {
  source = "../../"
}
EOF2

write_file "$BASE/terraform/environments/production/terraform.tfvars" <<'EOF2'
# optional per-environment overrides
EOF2

write_file "$BASE/terraform/README.md" <<'EOF2'
# Terraform

Root module for Proxmox VMs and LXCs.

Basic flow:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan
terraform apply
```

Notes:
- pfSense is a starter placeholder VM
- AI VM is a starter VM and should be extended for template clone and GPU passthrough
- LXCs assume a Debian 12 template exists in Proxmox
- LXCs bind-mount host storage into /mnt/appdata and /mnt/media_pool where required
- Terraform renders the Ansible inventory automatically
EOF2

# -----------------------------------------------------------------------------
# Terraform modules
# -----------------------------------------------------------------------------
make_module_tree "vm100-pfsense"
write_file "$BASE/terraform/modules/vm100-pfsense/variables.tf" <<'EOF2'
variable "proxmox_node" { type = string }
variable "vm_storage"   { type = string }
variable "vm_bridge"    { type = string }
variable "vm_vlan"      { type = number, default = null }
EOF2

write_file "$BASE/terraform/modules/vm100-pfsense/main.tf" <<'EOF2'
resource "proxmox_virtual_environment_vm" "this" {
  name      = "pfsense"
  node_name = var.proxmox_node
  vm_id     = 100
  started   = false
  on_boot   = true
  tags      = ["terraform", "firewall", "pfsense"]

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = 32
    file_format  = "raw"
  }

  network_device {
    bridge  = var.vm_bridge
    vlan_id = var.vm_vlan
  }

  operating_system {
    type = "other"
  }

  agent {
    enabled = false
  }

  description = "Starter pfSense VM. Attach ISO and finish install in Proxmox console."
}
EOF2

write_file "$BASE/terraform/modules/vm100-pfsense/outputs.tf" <<'EOF2'
output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}
EOF2

write_file "$BASE/terraform/modules/vm100-pfsense/README.md" <<'EOF2'
# vm100-pfsense

Starter pfSense VM placeholder.
Use this as the shell VM and attach a pfSense ISO manually or extend later.
EOF2

make_module_tree "vm210-ai-gpu"
write_file "$BASE/terraform/modules/vm210-ai-gpu/variables.tf" <<'EOF2'
variable "proxmox_node"      { type = string }
variable "vm_storage"        { type = string }
variable "cloudinit_storage" { type = string }
variable "vm_bridge"         { type = string }
variable "vm_vlan"           { type = number, default = null }
variable "ssh_public_key"    { type = string }
variable "ansible_user"      { type = string }
EOF2

write_file "$BASE/terraform/modules/vm210-ai-gpu/main.tf" <<'EOF2'
resource "proxmox_virtual_environment_vm" "this" {
  name      = "ai-gpu"
  node_name = var.proxmox_node
  vm_id     = 210
  started   = false
  on_boot   = true
  tags      = ["terraform", "ai", "gpu", "docker"]

  cpu {
    cores = 8
    type  = "host"
  }

  memory {
    dedicated = 32768
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = 128
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.cloudinit_storage

    ip_config {
      ipv4 {
        address = "10.10.66.210/24"
        gateway = "10.10.66.1"
      }
    }

    user_account {
      username = var.ansible_user
      keys     = var.ssh_public_key == "" ? [] : [var.ssh_public_key]
    }
  }

  network_device {
    bridge  = var.vm_bridge
    vlan_id = var.vm_vlan
  }

  operating_system {
    type = "l26"
  }

  description = "Starter AI VM. Extend later with template clone and GPU passthrough."
}
EOF2

write_file "$BASE/terraform/modules/vm210-ai-gpu/outputs.tf" <<'EOF2'
output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}
EOF2

write_file "$BASE/terraform/modules/vm210-ai-gpu/README.md" <<'EOF2'
# vm210-ai-gpu

Starter Linux VM for AI and Docker workloads.
Next step is usually template cloning and PCIe GPU passthrough.
EOF2

make_lxc_module() {
  local module="$1"
  local hostname="$2"
  local vmid="$3"
  local ip="$4"
  local disk="$5"
  local mem="$6"
  local cores="$7"
  local add_appdata="$8"
  local add_media_pool="$9"

  make_module_tree "$module"

  write_file "$BASE/terraform/modules/$module/variables.tf" <<'EOF2'
variable "proxmox_node"        { type = string }
variable "lxc_storage"         { type = string }
variable "vm_bridge"           { type = string }
variable "vm_vlan"             { type = number, default = null }
variable "ssh_public_key"      { type = string }
variable "debian_lxc_template" { type = string }
EOF2

  write_file "$BASE/terraform/modules/$module/main.tf" <<EOF2
resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.proxmox_node
  vm_id        = ${vmid}
  started      = false
  on_boot      = true
  unprivileged = true

  initialization {
    hostname = "${hostname}"

    ip_config {
      ipv4 {
        address = "${ip}/24"
        gateway = "10.10.66.1"
      }
    }

    user_account {
      password = "change-me-now"
      keys     = var.ssh_public_key == "" ? [] : [var.ssh_public_key]
    }
  }

  operating_system {
    template_file_id = var.debian_lxc_template
    type             = "debian"
  }

  cpu {
    cores = ${cores}
  }

  memory {
    dedicated = ${mem}
    swap      = 512
  }

  disk {
    datastore_id = var.lxc_storage
    size         = ${disk}
  }

  network_interface {
    name    = "eth0"
    bridge  = var.vm_bridge
    vlan_id = var.vm_vlan
  }

  features {
    nesting = true
    keyctl  = true
  }
$( if [[ "$add_appdata" == "true" ]]; then cat <<'MP'

  mount_point {
    volume = "/mnt/appdata"
    path   = "/mnt/appdata"
  }
MP
fi
)$( if [[ "$add_media_pool" == "true" ]]; then cat <<'MP'

  mount_point {
    volume = "/mnt/media_pool"
    path   = "/mnt/media_pool"
  }
MP
fi
)

  description = "Starter LXC for ${hostname}"
}
EOF2

  write_file "$BASE/terraform/modules/$module/outputs.tf" <<'EOF2'
output "vm_id" {
  value = proxmox_virtual_environment_container.this.vm_id
}
EOF2

  write_file "$BASE/terraform/modules/$module/README.md" <<EOF2
# ${module}

Starter Debian LXC for ${hostname}.
This module bind-mounts host storage where needed:
- /mnt/appdata for configs, docker volumes, and synced data
- /mnt/media_pool for media libraries and downloads
EOF2
}

make_lxc_module "lxc066-docker-arr"      "docker-arr"      66  "10.10.66.66"  32  4096 2 true  true
make_lxc_module "lxc200-docker-services" "docker-services" 200 "10.10.66.200" 64  8192 4 true  false
make_lxc_module "lxc220-docker-apps"     "docker-apps"     220 "10.10.66.220" 64  8192 4 true  false
make_lxc_module "lxc230-docker-media"    "docker-media"    230 "10.10.66.230" 64  8192 4 true  true
make_lxc_module "lxc240-docker-external" "docker-external" 240 "10.10.66.240" 32  4096 2 true  false
make_lxc_module "lxc250-infra"           "infra"           250 "10.10.66.250" 16  2048 2 true  false

# -----------------------------------------------------------------------------
# Ansible root
# -----------------------------------------------------------------------------
write_file "$BASE/ansible/ansible.cfg" <<'EOF2'
[defaults]
inventory = inventories/production/hosts.yml
roles_path = roles
host_key_checking = False
retry_files_enabled = False
interpreter_python = auto_silent
stdout_callback = yaml

[ssh_connection]
pipelining = True
EOF2

write_file "$BASE/ansible/inventories/production/group_vars/all.yml" <<'EOF2'
---
timezone: Europe/London
docker_compose_root: /opt/containers
appdata_root: /mnt/appdata
aI_models_root: /mnt/ai_models
ai_models_root: /mnt/ai_models
ai_cache_root: /mnt/ai_cache
media_root: /mnt/media_pool
ansible_python_interpreter: /usr/bin/python3
EOF2

touch "$BASE/ansible/inventories/production/host_vars/.gitkeep"

write_file "$BASE/ansible/playbooks/site.yml" <<'EOF2'
---
- name: Baseline for all Linux hosts
  hosts: docker_hosts:ai_gpu
  become: true
  roles:
    - common

- name: Install Docker on docker-capable hosts
  hosts: docker_hosts:ai_gpu
  become: true
  roles:
    - docker

- name: Configure AI GPU VM
  hosts: ai_gpu
  become: true
  roles:
    - vm210-ai-gpu

- name: Configure docker-arr host
  hosts: docker_arr
  become: true
  roles:
    - lxc066-docker-arr

- name: Configure docker-services host
  hosts: docker_services
  become: true
  roles:
    - lxc200-docker-services

- name: Configure docker-apps host
  hosts: docker_apps
  become: true
  roles:
    - lxc220-docker-apps

- name: Configure docker-media host
  hosts: docker_media
  become: true
  roles:
    - lxc230-docker-media

- name: Configure docker-external host
  hosts: docker_external
  become: true
  roles:
    - lxc240-docker-external

- name: Configure infra host
  hosts: infra
  become: true
  roles:
    - lxc250-infra
EOF2

write_file "$BASE/ansible/README.md" <<'EOF2'
# Ansible

Terraform renders the inventory to:

`inventories/production/hosts.yml`

Run:

```bash
ansible all -m ping
ansible-playbook playbooks/site.yml
```
EOF2

# -----------------------------------------------------------------------------
# Ansible roles
# -----------------------------------------------------------------------------
make_role_tree "common"
write_file "$BASE/ansible/roles/common/tasks/main.yml" <<'EOF2'
---
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600

- name: Install common packages
  ansible.builtin.apt:
    name:
      - curl
      - wget
      - git
      - vim
      - htop
      - ca-certificates
      - gnupg
      - python3
      - python3-pip
      - qemu-guest-agent
    state: present

- name: Set timezone
  community.general.timezone:
    name: "{{ timezone }}"

- name: Enable qemu guest agent
  ansible.builtin.service:
    name: qemu-guest-agent
    state: started
    enabled: true
  ignore_errors: true
EOF2

write_file "$BASE/ansible/roles/common/handlers/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/common/defaults/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/common/vars/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/common/meta/main.yml" <<'EOF2'
---
galaxy_info:
  author: Richard Wrightwells
  description: Common baseline role
  min_ansible_version: "2.14"
dependencies: []
EOF2

make_role_tree "docker"
write_file "$BASE/ansible/roles/docker/tasks/main.yml" <<'EOF2'
---
- name: Install Docker packages
  ansible.builtin.apt:
    name:
      - docker.io
      - docker-compose-plugin
      - python3-docker
    state: present
    update_cache: true

- name: Start Docker
  ansible.builtin.service:
    name: docker
    state: started
    enabled: true

- name: Ensure compose root exists
  ansible.builtin.file:
    path: "{{ docker_compose_root }}"
    state: directory
    owner: root
    group: root
    mode: "0755"
EOF2

write_file "$BASE/ansible/roles/docker/handlers/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/docker/defaults/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/docker/vars/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/docker/meta/main.yml" <<'EOF2'
---
galaxy_info:
  author: Richard Wrightwells
  description: Install Docker engine
  min_ansible_version: "2.14"
dependencies: []
EOF2

make_compose_role() {
  local role="$1"
  shift
  local items=("$@")

  make_role_tree "$role"

  {
    echo '---'
    echo '- name: Ensure compose root exists'
    echo '  ansible.builtin.file:'
    echo '    path: "{{ docker_compose_root }}"'
    echo '    state: directory'
    echo '    owner: root'
    echo '    group: root'
    echo '    mode: "0755"'
    echo
    echo '- name: Ensure application directories exist'
    echo '  ansible.builtin.file:'
    echo '    path: "{{ docker_compose_root }}/{{ item }}"'
    echo '    state: directory'
    echo '    owner: root'
    echo '    group: root'
    echo '    mode: "0755"'
    echo '  loop:'
    for item in "${items[@]}"; do
      echo "    - $item"
    done
    echo
    echo '- name: Copy compose files'
    echo '  ansible.builtin.copy:'
    echo '    src: "{{ item }}/"'
    echo '    dest: "{{ docker_compose_root }}/{{ item }}/"'
    echo '    owner: root'
    echo '    group: root'
    echo '    mode: preserve'
    echo '  loop:'
    for item in "${items[@]}"; do
      echo "    - $item"
    done
    echo
    echo '- name: Start compose stacks'
    echo '  community.docker.docker_compose_v2:'
    echo '    project_src: "{{ docker_compose_root }}/{{ item }}"'
    echo '    state: present'
    echo '  loop:'
    for item in "${items[@]}"; do
      echo "    - $item"
    done
  } > "$BASE/ansible/roles/$role/tasks/main.yml"

  write_file "$BASE/ansible/roles/$role/handlers/main.yml" <<'EOF2'
---
EOF2
  write_file "$BASE/ansible/roles/$role/defaults/main.yml" <<'EOF2'
---
EOF2
  write_file "$BASE/ansible/roles/$role/vars/main.yml" <<'EOF2'
---
EOF2
  write_file "$BASE/ansible/roles/$role/meta/main.yml" <<EOF2
---
galaxy_info:
  author: Richard Wrightwells
  description: Configure host role $role
  min_ansible_version: "2.14"
dependencies: []
EOF2
}

make_role_tree "vm100-pfsense"
write_file "$BASE/ansible/roles/vm100-pfsense/tasks/main.yml" <<'EOF2'
---
- name: pfSense placeholder
  ansible.builtin.debug:
    msg: "pfSense is usually managed from pfSense itself or via API later."
EOF2
write_file "$BASE/ansible/roles/vm100-pfsense/handlers/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/vm100-pfsense/defaults/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/vm100-pfsense/vars/main.yml" <<'EOF2'
---
EOF2
write_file "$BASE/ansible/roles/vm100-pfsense/meta/main.yml" <<'EOF2'
---
galaxy_info:
  author: Richard Wrightwells
  description: pfSense placeholder role
  min_ansible_version: "2.14"
dependencies: []
EOF2

make_compose_role "vm210-ai-gpu" "frigate" "home-assistant" "ai-models"
make_compose_role "lxc066-docker-arr" "filebrowser" "jellyseerr" "aurral" "arr-stack"
make_compose_role "lxc200-docker-services" "immich" "owncloud" "syncthing"
make_compose_role "lxc220-docker-apps" "grafana" "influxdb" "node-red" "teslamate" "homebridge" "calibre" "calibre-web" "grist" "blinko" "finance"
make_compose_role "lxc230-docker-media" "plex" "jellyfin"
make_compose_role "lxc240-docker-external" "nginx" "tailscale-peer-relay" "jellyswarm" "ghost" "dnns" "kutt" "wordpress" "walletpage"
make_compose_role "lxc250-infra" "mqtt" "homebridge" "nginx"

# -----------------------------------------------------------------------------
# Compose files
# -----------------------------------------------------------------------------
make_compose() {
  local rel="$1"
  local service="$2"
  local image="$3"
  local ports="$4"
  local volumes="$5"

  mkdir -p "$BASE/ansible/files/compose/$rel"

  write_file "$BASE/ansible/files/compose/$rel/docker-compose.yml" <<EOF2
services:
  ${service}:
    image: ${image}
    container_name: ${service}
    restart: unless-stopped
    environment:
      - TZ=Europe/London
    ${ports}
    ${volumes}
EOF2

  write_file "$BASE/ansible/files/compose/$rel/.env.example" <<'EOF2'
PUID=1000
PGID=1000
TZ=Europe/London
EOF2
}

make_compose "vm210-ai-gpu/frigate" "frigate" "ghcr.io/blakeblackshear/frigate:stable" \
'ports:
      - "5000:5000"' \
'volumes:
      - /mnt/appdata/configs/frigate:/config
      - /mnt/ai_cache/frigate_recordings:/media/frigate
      - /etc/localtime:/etc/localtime:ro'

make_compose "vm210-ai-gpu/home-assistant" "homeassistant" "ghcr.io/home-assistant/home-assistant:stable" \
'ports:
      - "8123:8123"' \
'volumes:
      - /mnt/appdata/configs/home-assistant:/config
      - /etc/localtime:/etc/localtime:ro'

make_compose "vm210-ai-gpu/ai-models" "ollama" "ollama/ollama:latest" \
'ports:
      - "11434:11434"' \
'volumes:
      - /mnt/ai_models:/root/.ollama/models
      - /mnt/ai_cache/ollama:/root/.ollama'

make_compose "lxc200-docker-services/immich" "immich" "ghcr.io/immich-app/immich-server:release" \
'ports:
      - "2283:2283"' \
'volumes:
      - /mnt/appdata/docker_volumes/immich:/usr/src/app/upload
      - /mnt/media_pool/photos:/external'

make_compose "lxc200-docker-services/owncloud" "owncloud" "owncloud/server:latest" \
'ports:
      - "8080:8080"' \
'volumes:
      - /mnt/appdata/docker_volumes/owncloud:/mnt/data'

make_compose "lxc200-docker-services/syncthing" "syncthing" "lscr.io/linuxserver/syncthing:latest" \
'ports:
      - "8384:8384"
      - "22000:22000/tcp"
      - "22000:22000/udp"
      - "21027:21027/udp"' \
'volumes:
      - /mnt/appdata/docker_volumes/syncthing/config:/config
      - /mnt/appdata/syncthing_sync:/data'

make_compose "lxc230-docker-media/plex" "plex" "lscr.io/linuxserver/plex:latest" \
'ports:
      - "32400:32400"' \
'volumes:
      - /mnt/appdata/docker_volumes/plex:/config
      - /mnt/media_pool:/media'

make_compose "lxc230-docker-media/jellyfin" "jellyfin" "lscr.io/linuxserver/jellyfin:latest" \
'ports:
      - "8096:8096"' \
'volumes:
      - /mnt/appdata/docker_volumes/jellyfin:/config
      - /mnt/media_pool:/media'

make_compose "lxc066-docker-arr/filebrowser" "filebrowser" "filebrowser/filebrowser:latest" \
'ports:
      - "8081:80"' \
'volumes:
      - /mnt/media_pool:/srv
      - /mnt/appdata/docker_volumes/filebrowser/database:/database'

make_compose "lxc066-docker-arr/jellyseerr" "jellyseerr" "fallenbagel/jellyseerr:latest" \
'ports:
      - "5055:5055"' \
'volumes:
      - /mnt/appdata/docker_volumes/jellyseerr:/app/config'

make_compose "lxc066-docker-arr/aurral" "aurral" "ghcr.io/lklynet/aurral:latest" \
'ports:
      - "3000:3000"' \
'volumes:
      - /mnt/appdata/docker_volumes/aurral:/app/backend/data
      - /mnt/media_pool/torrents:/app/downloads'

write_file "$BASE/ansible/files/compose/lxc066-docker-arr/arr-stack/docker-compose.yml" <<'EOF2'
services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    ports:
      - "9696:9696"
    environment:
      - TZ=Europe/London
    volumes:
      - /mnt/appdata/docker_volumes/prowlarr:/config

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    ports:
      - "8989:8989"
    environment:
      - TZ=Europe/London
    volumes:
      - /mnt/appdata/docker_volumes/sonarr:/config
      - /mnt/media_pool:/media

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    ports:
      - "7878:7878"
    environment:
      - TZ=Europe/London
    volumes:
      - /mnt/appdata/docker_volumes/radarr:/config
      - /mnt/media_pool:/media

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    restart: unless-stopped
    ports:
      - "8686:8686"
    environment:
      - TZ=Europe/London
    volumes:
      - /mnt/appdata/docker_volumes/lidarr:/config
      - /mnt/media_pool:/media

  readarr:
    image: lscr.io/linuxserver/readarr:latest
    container_name: readarr
    restart: unless-stopped
    ports:
      - "8787:8787"
    environment:
      - TZ=Europe/London
    volumes:
      - /mnt/appdata/docker_volumes/readarr:/config
      - /mnt/media_pool:/media

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    ports:
      - "8082:8080"
      - "6881:6881"
      - "6881:6881/udp"
    environment:
      - TZ=Europe/London
    volumes:
      - /mnt/appdata/docker_volumes/qbittorrent:/config
      - /mnt/media_pool/torrents:/downloads
EOF2

write_file "$BASE/ansible/files/compose/lxc066-docker-arr/arr-stack/.env.example" <<'EOF2'
PUID=1000
PGID=1000
TZ=Europe/London
EOF2

make_compose "lxc220-docker-apps/grafana" "grafana" "grafana/grafana:latest" \
'ports:
      - "3001:3000"' \
'volumes:
      - /mnt/appdata/docker_volumes/grafana:/var/lib/grafana'

make_compose "lxc220-docker-apps/influxdb" "influxdb" "influxdb:2" \
'ports:
      - "8086:8086"' \
'volumes:
      - /mnt/appdata/docker_volumes/influxdb:/var/lib/influxdb2'

make_compose "lxc220-docker-apps/node-red" "nodered" "nodered/node-red:latest" \
'ports:
      - "1880:1880"' \
'volumes:
      - /mnt/appdata/configs/node-red:/data'

make_compose "lxc220-docker-apps/teslamate" "teslamate" "teslamate/teslamate:latest" \
'ports:
      - "4000:4000"' \
'volumes:
      - /mnt/appdata/docker_volumes/teslamate:/opt/app/data'

make_compose "lxc220-docker-apps/homebridge" "homebridge" "homebridge/homebridge:latest" \
'ports:
      - "8581:8581"' \
'volumes:
      - /mnt/appdata/configs/homebridge:/homebridge'

make_compose "lxc220-docker-apps/calibre" "calibre" "lscr.io/linuxserver/calibre:latest" \
'ports:
      - "8083:8080"
      - "8181:8181"' \
'volumes:
      - /mnt/appdata/docker_volumes/calibre:/config'

make_compose "lxc220-docker-apps/calibre-web" "calibre-web" "lscr.io/linuxserver/calibre-web:latest" \
'ports:
      - "8084:8083"' \
'volumes:
      - /mnt/appdata/docker_volumes/calibre-web:/config
      - /mnt/media_pool/books:/books'

make_compose "lxc220-docker-apps/grist" "grist" "gristlabs/grist:latest" \
'ports:
      - "8484:8484"' \
'volumes:
      - /mnt/appdata/docker_volumes/grist:/persist'

make_compose "lxc220-docker-apps/blinko" "blinko" "blinko/blinko:latest" \
'ports:
      - "1111:1111"' \
'volumes:
      - /mnt/appdata/docker_volumes/blinko:/app/data'

make_compose "lxc220-docker-apps/finance" "finance" "fireflyiii/core:latest" \
'ports:
      - "8085:8080"' \
'volumes:
      - /mnt/appdata/docker_volumes/firefly:/var/www/html/storage/upload'

make_compose "lxc240-docker-external/nginx" "nginx" "nginx:latest" \
'ports:
      - "80:80"
      - "443:443"' \
'volumes:
      - /mnt/appdata/configs/nginx:/etc/nginx/conf.d
      - /mnt/appdata/docker_volumes/nginx/html:/usr/share/nginx/html'

make_compose "lxc240-docker-external/tailscale-peer-relay" "tailscale" "tailscale/tailscale:latest" \
'ports:
      - "41641:41641/udp"' \
'volumes:
      - /mnt/appdata/docker_volumes/tailscale:/var/lib/tailscale'

make_compose "lxc240-docker-external/jellyswarm" "jellyswarm" "ghcr.io/jellyswarm/jellyswarm:latest" \
'ports:
      - "5056:5055"' \
'volumes:
      - /mnt/appdata/docker_volumes/jellyswarm:/config'

make_compose "lxc240-docker-external/ghost" "ghost" "ghost:latest" \
'ports:
      - "2368:2368"' \
'volumes:
      - /mnt/appdata/docker_volumes/ghost:/var/lib/ghost/content'

make_compose "lxc240-docker-external/dnns" "dnns" "ghcr.io/n00bcodr/dnns:latest" \
'ports:
      - "8090:8080"' \
'volumes:
      - /mnt/appdata/docker_volumes/dnns:/app/data'

make_compose "lxc240-docker-external/kutt" "kutt" "kutt/kutt:latest" \
'ports:
      - "3002:3000"' \
'volumes:
      - /mnt/appdata/docker_volumes/kutt:/kutt'

make_compose "lxc240-docker-external/wordpress" "wordpress" "wordpress:latest" \
'ports:
      - "8088:80"' \
'volumes:
      - /mnt/appdata/docker_volumes/wordpress:/var/www/html'

make_compose "lxc240-docker-external/walletpage" "walletpage" "nginx:latest" \
'ports:
      - "8089:80"' \
'volumes:
      - /mnt/appdata/docker_volumes/walletpage:/usr/share/nginx/html'

make_compose "lxc250-infra/mqtt" "mosquitto" "eclipse-mosquitto:latest" \
'ports:
      - "1883:1883"
      - "9001:9001"' \
'volumes:
      - /mnt/appdata/docker_volumes/mosquitto/config:/mosquitto/config
      - /mnt/appdata/docker_volumes/mosquitto/data:/mosquitto/data
      - /mnt/appdata/docker_volumes/mosquitto/log:/mosquitto/log'

make_compose "lxc250-infra/homebridge" "homebridge" "homebridge/homebridge:latest" \
'ports:
      - "8582:8581"' \
'volumes:
      - /mnt/appdata/configs/homebridge:/homebridge'

make_compose "lxc250-infra/nginx" "nginx" "nginx:latest" \
'ports:
      - "8087:80"' \
'volumes:
      - /mnt/appdata/configs/nginx-infra:/etc/nginx/conf.d
      - /mnt/appdata/docker_volumes/nginx-infra/html:/usr/share/nginx/html'

# -----------------------------------------------------------------------------
# Helper scripts
# -----------------------------------------------------------------------------
write_file "$BASE/scripts/terraform-init.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../terraform"
terraform init
EOF2

write_file "$BASE/scripts/terraform-plan.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../terraform"
terraform plan
EOF2

write_file "$BASE/scripts/terraform-apply.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../terraform"
terraform apply
EOF2

write_file "$BASE/scripts/ansible-ping.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../ansible"
ansible all -m ping
EOF2

write_file "$BASE/scripts/deploy-all.sh" <<'EOF2'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$ROOT/terraform" && terraform init)
(cd "$ROOT/terraform" && terraform apply)
(cd "$ROOT/ansible" && ansible all -m ping)
(cd "$ROOT/ansible" && ansible-playbook playbooks/site.yml)
EOF2

chmod +x "$BASE/scripts/"*.sh

# -----------------------------------------------------------------------------
# Root repo files
# -----------------------------------------------------------------------------
write_file "$BASE/README.md" <<'EOF2'
# HomeLab

Infrastructure-as-code repository for a Proxmox homelab.

## Hosts

- VM100 pfSense
- VM210 AI-GPU
- LXC066 docker-arr
- LXC200 docker-services
- LXC220 docker-apps
- LXC230 docker-media
- LXC240 docker-external
- LXC250 infra

## Storage model

- NVMe 500GB: /mnt/ai_models, /mnt/ai_cache, Frigate recordings, LLM cache
- SSD 500GB: Proxmox OS, Terraform repo, LXC rootfs, VM root disks, Docker runtime
- RAID1 2x4TB: /mnt/appdata for config, databases, Docker volumes, Syncthing critical data
- Media pool 4x12TB: /mnt/media_pool via mergerfs
EOF2

write_file "$BASE/.gitignore" <<'EOF2'
**/.terraform/*
*.tfstate
*.tfstate.*
crash.log
*.tfvars
!.tfvars.example
*.retry
.env
.env.*
.vscode/
.DS_Store
Thumbs.db
EOF2

echo
echo "Done."
echo "Starter scaffold created under: $BASE"
echo
echo "Next steps:"
echo "1. cp $BASE/terraform/terraform.tfvars.example $BASE/terraform/terraform.tfvars"
echo "2. Edit the real Proxmox values"
echo "3. Ensure Proxmox host paths exist: /mnt/appdata /mnt/media_pool /mnt/ai_models /mnt/ai_cache"
echo "4. cd $BASE/terraform && terraform init && terraform validate"
echo "5. terraform plan"
echo "6. terraform apply"

