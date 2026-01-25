#!/bin/bash
set -e
source "$(dirname "$0")/config-gke-cluster.sh"

# Enable required services
enable_services

# Set up GKE Cluster
echo "Setting up GKE Cluster..."

gcloud container clusters create "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --num-nodes="${NUM_NODES}" \
  --disk-size="${DISK_SIZE}" \
  --machine-type="${MACHINE_TYPE}" \
  --release-channel="${RELEASE_CHANNEL}" \
  $( [ "$ENABLE_IP_ALIAS" = true ] && echo "--enable-ip-alias" ) \
  $( [ "$ENABLE_SHIELDED_NODES" = true ] && echo "--shielded-secure-boot --shielded-integrity-monitoring" )

echo "GKE Cluster setup complete."
connect_cluster