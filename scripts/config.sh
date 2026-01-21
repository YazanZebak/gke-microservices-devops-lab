#!/bin/bash
set -e

# Global Variables
export PROJECT_ID="project-caf6a8f5-fd1c-496d-8d2"
export REGION="europe-west9"  # Paris

# GKE Cluster Name
export CLUSTER_NAME="online-boutique"

# Enable Required Services
enable_services() {
    echo "Enabling required services..."
    gcloud services enable container.googleapis.com compute.googleapis.com  --project="${PROJECT_ID}"
}

# Connect to GKE Cluster
connect_cluster() {
    echo "Connecting to GKE Cluster..."
    gcloud container clusters get-credentials ${CLUSTER_NAME} --region=${REGION} --project=${PROJECT_ID}
}
