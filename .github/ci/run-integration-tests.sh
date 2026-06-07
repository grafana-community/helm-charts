#!/usr/bin/env bash
set -euo pipefail

CHART="$1"
CHART_NAME=$(basename "$CHART")
NAMESPACE="integration-${CHART_NAME}-${GITHUB_RUN_ID:-local}"

cleanup() {
  helm uninstall "$CHART_NAME" --namespace "$NAMESPACE" --wait --timeout 120s 2>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
}
trap cleanup EXIT

kubectl create namespace "$NAMESPACE"

helm dependency update "$CHART"
helm install "$CHART_NAME" "$CHART" \
  --namespace "$NAMESPACE" \
  --values "$CHART/ci/integration/values.yaml" \
  --set tests.integration.enabled=true \
  --wait --timeout 600s

helm test "$CHART_NAME" --namespace "$NAMESPACE" --logs --timeout 600s
