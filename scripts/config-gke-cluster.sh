#!/bin/bash
set -e

# Project & Region
export PROJECT_ID="project-65307ab8-ddea-48bf-b28"
export REGION="europe-west1" # Brussels
export ZONE="europe-west1-b"

# GKE Cluster
export CLUSTER_NAME="online-boutique"
export RELEASE_CHANNEL="regular"

# Node Pool
export NUM_NODES=2
export MACHINE_TYPE="e2-standard-2"
export DISK_SIZE=30

# Network & Security
export ENABLE_IP_ALIAS=true
export ENABLE_SHIELDED_NODES=true

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
