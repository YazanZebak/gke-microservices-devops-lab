#!/bin/bash
set -e

# Global Variables
export PROJECT_ID="i-hexagon-438514-g4"
export REGION="us-central1-a"

# GKE Cluster Name
export CLUSTER_NAME="online-boutique"

# Enable Required Services
enable_services() {
    echo "Enabling required services..."
    gcloud services enable container.googleapis.com compute.googleapis.com
}

# Connect to GKE Cluster
connect_cluster() {
    echo "Connecting to GKE Cluster..."
    gcloud container clusters get-credentials ${CLUSTER_NAME} --region=${REGION} --project=${PROJECT_ID}
}
