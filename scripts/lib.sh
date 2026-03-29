# lib.sh — shared functions, sourced by scripts that need them
set -e
source "$(dirname "${BASH_SOURCE[0]}")/config-gke-cluster.sh"

enable_services() {
    echo "Enabling required services..."
    gcloud services enable container.googleapis.com compute.googleapis.com \
      --project="${PROJECT_ID}"
}

connect_cluster() {
    echo "Connecting to GKE cluster..."
    gcloud container clusters get-credentials "${CLUSTER_NAME}" \
      --region="${REGION}" \
      --project="${PROJECT_ID}"
}
