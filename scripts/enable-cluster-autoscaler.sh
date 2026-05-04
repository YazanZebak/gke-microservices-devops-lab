#!/bin/bash
# enable-cluster-autoscaler.sh
# Enables Cluster Autoscaler on the existing node pool.
# Min 2 nodes (baseline), max 4 nodes (burst headroom).
# Run this once after cluster creation if CA is needed.
set -e
source "$(dirname "$0")/lib.sh"

NODE_POOL="default-pool"
MIN_NODES=2
MAX_NODES=4

echo "Enabling Cluster Autoscaler on node pool '${NODE_POOL}'..."

gcloud container clusters update "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --enable-autoscaling \
  --node-pool="${NODE_POOL}" \
  --min-nodes="${MIN_NODES}" \
  --max-nodes="${MAX_NODES}"

echo "Cluster Autoscaler enabled: min=${MIN_NODES}, max=${MAX_NODES} nodes."