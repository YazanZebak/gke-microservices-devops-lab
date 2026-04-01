#!/bin/bash
set -e
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "Destroying Terraform infrastructure..."
cd "$(dirname "${BASH_SOURCE[0]}")/../infrastructure/terraform"

terraform destroy -auto-approve

echo "Terraform infrastructure destroyed."