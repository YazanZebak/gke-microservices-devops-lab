#!/bin/bash
set -e
source "$(dirname "$0")/config-gke-cluster.sh"

# Connect to GKE Cluster
connect_cluster

# Deploy Application
echo "Deploying Kubernetes manifests..."
kubectl apply -f ./microservices-demo/kubernetes-manifests/

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all --timeout=600s