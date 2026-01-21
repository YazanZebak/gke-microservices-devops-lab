#!/bin/bash
set -e
source "$(dirname "$0")/config-gke-cluster.sh"

# Delete GKE Cluster
echo "Deleting GKE Cluster..."
gcloud container clusters delete ${CLUSTER_NAME} --region=${REGION} --quiet
