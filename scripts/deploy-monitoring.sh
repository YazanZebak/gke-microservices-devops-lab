#!/bin/bash
set -e
source "$(dirname "$0")/lib.sh"

connect_cluster

echo "Adding prometheus-community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Deploying kube-prometheus-stack..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values "$(dirname "$0")/../infrastructure/helm/monitoring/values.yaml" \
  --wait

echo ""
echo "Waiting for Grafana LoadBalancer IP..."
TIMEOUT=120
ELAPSED=0
INTERVAL=5
while true; do
  GRAFANA_IP=$(kubectl get svc monitoring-grafana \
    -n monitoring \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  if [[ -n "$GRAFANA_IP" ]]; then
    echo "Grafana available at: http://${GRAFANA_IP}"
    echo "Credentials: admin / admin"
    break
  fi

  if (( ELAPSED >= TIMEOUT )); then
    echo "Timed out waiting for Grafana IP. Check: kubectl get svc -n monitoring"
    exit 1
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done