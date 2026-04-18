#!/bin/bash
set -e
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"

echo "=== Starting teardown ==="

# 1. Destroy load generator VM
echo "Destroying load generator VM..."
if [ -d "$(dirname "${BASH_SOURCE[0]}")/../infrastructure/terraform/.terraform" ]; then
  "${SCRIPTS_DIR}/destroy-loadgenerator.sh"
else
  echo "Terraform not initialized, skipping."
fi

# 2. Remove monitoring stack
echo "Removing monitoring stack..."
if helm status monitoring -n monitoring &>/dev/null; then
  "${SCRIPTS_DIR}/destroy-monitoring.sh"
else
  echo "Monitoring stack not found, skipping."
fi

# 3. Delete GKE cluster
echo "Deleting GKE cluster..."
"${SCRIPTS_DIR}/delete-gke-cluster.sh"

echo ""
echo "=== Teardown complete. No billable resources remaining. ==="