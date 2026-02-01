#!/bin/bash
set -e
source "$(dirname "$0")/config-gke-cluster.sh"

connect_cluster

SERVICE_NAME=frontend-external
NAMESPACE=default
TIMEOUT=120
INTERVAL=5
ELAPSED=0

while true; do
  FRONTEND_IP=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  FRONTEND_HOSTNAME=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

  if [[ -n "$FRONTEND_IP" ]]; then
    ENDPOINT="$FRONTEND_IP"
    break
  elif [[ -n "$FRONTEND_HOSTNAME" ]]; then
    ENDPOINT="$FRONTEND_HOSTNAME"
    break
  fi

  if (( ELAPSED >= TIMEOUT )); then
    echo "Error: LoadBalancer endpoint not assigned after ${TIMEOUT}s"
    exit 1
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "Application available at: http://${ENDPOINT}"
