# Sizing Guide

This guide describes the sizing system that is now implemented in Terraform for
your current host plan:

- 12 cores / 24 threads
- 32 GB RAM now
- 64 GB RAM later
- 128 GB RAM later

Use [README-bootstrap.md](/home/ww/HomeLab/HomeLab/README-bootstrap.md) as the
main runbook. This file is the sizing sub-guide for choosing and changing
resource profiles over time.

## How Sizing Works Now

Terraform no longer relies on fixed CPU and memory values inside each guest
module.

Instead, the root module selects a profile with:

- `resource_profile`

That profile controls:

- CPU cores
- RAM
- swap for LXCs
- whether the guest should be started after apply
- whether the guest should auto-start on host boot

Relevant files:

- [variables.tf](/home/ww/HomeLab/HomeLab/terraform/variables.tf)
- [main.tf](/home/ww/HomeLab/HomeLab/terraform/main.tf)
- [terraform.tfvars.example](/home/ww/HomeLab/HomeLab/terraform/terraform.tfvars.example)

## Available Profiles

The current profiles are:

- `balanced_32gb`
- `ai_focus_32gb`
- `balanced_64gb`
- `ai_focus_64gb`
- `balanced_128gb`
- `ai_focus_128gb`

The current default is:

- `balanced_32gb`

## Current Default Plan

The repo is currently set up to start from:

```hcl
resource_profile = "balanced_32gb"
```

That profile is the minimal practical starting point for your current 32 GB
host.

### `balanced_32gb`

- `vm100_pfsense`: 2 cores, 4 GB, starts automatically
- `vm210_ai_gpu`: 4 cores, 12 GB, stays off by default
- `lxc066_docker_arr`: 2 cores, 4 GB, starts automatically
- `lxc200_docker_services`: 2 cores, 6 GB, starts automatically
- `lxc220_docker_apps`: 2 cores, 4 GB, starts automatically
- `lxc230_docker_media`: 2 cores, 4 GB, starts automatically
- `lxc240_docker_external`: 2 cores, 3 GB, starts automatically
- `lxc250_infra`: 1 core, 2 GB, starts automatically

Why this is the default:

- it keeps the always-on services reasonably small
- it avoids giving the AI VM all available RAM on day one
- it lets you bring up the core homelab first

Important:

- this is still a fairly full 32 GB host
- the AI VM is intentionally not set to auto-start in this profile

## AI-Focused Profiles

Each host-memory tier also has an AI-focused profile.

These are designed for the case where:

- pfSense should be running
- the AI VM should be running
- the other LXCs should stay stopped

That matches your request for a mode where the AI server can take most of the
available memory for that stage of the host.

### `ai_focus_32gb`

- `vm100_pfsense`: 2 cores, 4 GB, starts automatically
- `vm210_ai_gpu`: 8 cores, 24 GB, starts automatically
- all LXCs: configured but not started and not set to auto-start

This is the “AI mode” for the current 32 GB host.

### `ai_focus_64gb`

- `vm100_pfsense`: 2 cores, 4 GB, starts automatically
- `vm210_ai_gpu`: 12 cores, 52 GB, starts automatically
- all LXCs: configured but not started and not set to auto-start

### `ai_focus_128gb`

- `vm100_pfsense`: 2 cores, 4 GB, starts automatically
- `vm210_ai_gpu`: 16 cores, 112 GB, starts automatically
- all LXCs: configured but not started and not set to auto-start

## Balanced Growth Profiles

These profiles are intended for normal multi-service operation as the host is
upgraded.

### `balanced_64gb`

- `vm100_pfsense`: 2 cores, 4 GB
- `vm210_ai_gpu`: 8 cores, 24 GB
- `lxc066_docker_arr`: 2 cores, 4 GB
- `lxc200_docker_services`: 4 cores, 8 GB
- `lxc220_docker_apps`: 3 cores, 6 GB
- `lxc230_docker_media`: 3 cores, 6 GB
- `lxc240_docker_external`: 2 cores, 4 GB
- `lxc250_infra`: 2 cores, 2 GB

This is the recommended next step once the host reaches 64 GB.

### `balanced_128gb`

- `vm100_pfsense`: 2 cores, 4 GB
- `vm210_ai_gpu`: 12 cores, 48 GB
- `lxc066_docker_arr`: 2 cores, 4 GB
- `lxc200_docker_services`: 4 cores, 10 GB
- `lxc220_docker_apps`: 4 cores, 8 GB
- `lxc230_docker_media`: 4 cores, 8 GB
- `lxc240_docker_external`: 2 cores, 4 GB
- `lxc250_infra`: 2 cores, 4 GB

This is the comfortable “everything can breathe” profile.

## Recommended Use Over Time

### Right now on 32 GB

Use:

```hcl
resource_profile = "balanced_32gb"
```

Use `ai_focus_32gb` only when you want the host acting primarily as the AI box.

### After upgrading to 64 GB

Use:

```hcl
resource_profile = "balanced_64gb"
```

Or:

```hcl
resource_profile = "ai_focus_64gb"
```

if you want to temporarily prioritize the AI VM.

### After upgrading to 128 GB

Use:

```hcl
resource_profile = "balanced_128gb"
```

Or:

```hcl
resource_profile = "ai_focus_128gb"
```

for heavy AI usage.

## How To Change Profiles

Change only this in:

- [terraform.tfvars](/home/ww/HomeLab/HomeLab/terraform/terraform.tfvars)

Example:

```hcl
resource_profile = "balanced_64gb"
```

Then run your usual Terraform plan/apply flow.

## Startup Behavior

Startup policy is also profile-driven now.

That means the selected profile decides:

- which guests should start after `terraform apply`
- which guests should auto-start when Proxmox boots

In practice:

- balanced profiles start the normal service set
- AI-focused profiles keep the non-AI LXCs off

## Notes

- pfSense stays small and consistent across profiles because it is a critical
  infrastructure service, not a burst workload
- the AI VM is the main lever for memory growth across profiles
- the LXC groups scale more gradually because most of them are service bundles,
  not single heavy applications
