#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"

connect_cluster

echo "Removing kube-prometheus-stack..."
helm uninstall monitoring --namespace monitoring

echo "Deleting monitoring namespace..."
kubectl delete namespace monitoring

echo "Monitoring stack removed."