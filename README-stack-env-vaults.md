# Stack Env Vault Script

This guide explains the helper script for rotating Ansible `stack.env.vault`
files inside the Docker compose tree.

The script searches only the compose-related Ansible folder structure:

```text
ansible/files/compose/
```

It does not scan the whole repo.

## Script

- [stack-env-vault-rotate.sh](scripts/stack-env-vault-rotate.sh)

## What The Script Does

Given:

- a source vault password
- a target vault password

the script will:

1. search for any `stack.env.vault` files under `ansible/files/compose/`
2. decrypt each one to a sibling `stack.env`
3. leave the plain `stack.env` on disk
4. re-encrypt each `stack.env` to `stack.env.vault` using the target password
5. also encrypt any existing plain `stack.env` files it finds under that same tree

So after the script runs:

- plain `stack.env` files remain on disk
- `stack.env.vault` files are recreated or refreshed with the new password

## Requirements

You need:

- `ansible-vault` available in `PATH`
- the current vault password
- the new vault password

## Usage

From the repo root:

```bash
./scripts/stack-env-vault-rotate.sh \
  --source-password 'old-password' \
  --target-password 'new-password'
```

Optional:

```bash
./scripts/stack-env-vault-rotate.sh \
  --source-password 'old-password' \
  --target-password 'new-password' \
  --search-root /path/to/repo/ansible/files/compose
```

## Typical Workflow

Example:

```bash
./scripts/stack-env-vault-rotate.sh \
  --source-password 'old-password' \
  --target-password 'new-password'
```

## Important Notes

- The script accepts passwords on the command line and writes temporary password
  files only in a private temporary directory during execution.
- Those temporary files are removed automatically when the script exits.
- The script intentionally leaves decrypted `stack.env` files on disk.
- That means you should treat the repo working tree as containing plain-text
  secrets after the script runs.
- Review, move, or remove those plain files as needed after you finish.
- The script only works on the compose stack layout under `ansible/files/compose/`.
- It does not modify `stack.env.example`.

## When To Use It

Use this script when you want to:

- rotate the vault password used for `stack.env.vault`
- generate plain `stack.env` files for review or migration
- create new vaulted copies for any plain `stack.env` files already present in
  the compose tree
