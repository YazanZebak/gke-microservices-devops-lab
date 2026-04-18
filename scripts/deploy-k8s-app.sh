#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"

# Connect to GKE Cluster
connect_cluster

# Install Istio
echo "Installing Istio..."
istioctl install --set profile=demo -y

# Enable sidecar injection
echo "Enabling Istio sidecar injection..."
kubectl label namespace default istio-injection=enabled --overwrite

# Install Kiali and link to existing Prometheus
echo "Installing Kiali..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Point Kiali at the existing kube-prometheus-stack instance
kubectl patch configmap kiali -n istio-system --type merge -p '{
  "data": {
    "config.yaml": "external_services:\n  prometheus:\n    url: \"http://monitoring-kube-prometheus-prometheus.monitoring:9090\"\n"
  }
}'

# Deploy Application
echo "Deploying Kubernetes manifests..."
kubectl apply -k overlays

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all --timeout=600s

echo "Restarting pods to inject Istio sidecars..."
kubectl rollout restart deployment -n default
kubectl wait --for=condition=ready pod --all --timeout=600s

echo "Deployment complete."