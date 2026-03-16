# Ansible
#
# This directory should contain:
# - inventory
# - group_vars
# - host_vars
# - playbooks
# - roles
# - compose files for deployment
#
# Intended flow:
# 1. Terraform provisions hosts
# 2. Terraform renders Ansible inventory
# 3. Ansible configures hosts
# 4. Compose or service definitions are deployed
