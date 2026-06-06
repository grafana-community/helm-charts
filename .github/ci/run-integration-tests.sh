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
  --values "$CHART/integration-tests/values.yaml" \
  --wait --timeout 600s

kubectl create configmap bats-tests \
  --namespace "$NAMESPACE" \
  --from-file="$CHART/integration-tests/"

kubectl apply --namespace "$NAMESPACE" -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: bats-integration-test
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: bats
          image: alpine:3.21
          command:
            - sh
            - -c
            - apk add --no-cache bash bats curl && bats /tests/*.bats
          volumeMounts:
            - name: tests
              mountPath: /tests
      volumes:
        - name: tests
          configMap:
            name: bats-tests
EOF

echo "Waiting for integration tests to complete..."
DEADLINE=$(( $(date +%s) + 600 ))
PHASE=""
while true; do
  PHASE=$(kubectl get pods -l job-name=bats-integration-test \
    --namespace "$NAMESPACE" \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")

  if [ "$PHASE" = "Succeeded" ] || [ "$PHASE" = "Failed" ]; then
    break
  fi

  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    echo "Integration tests timed out after 10 minutes"
    PHASE="Failed"
    break
  fi

  sleep 5
done

echo "--- integration test output ---"
kubectl logs -l job-name=bats-integration-test --namespace "$NAMESPACE" --tail=-1

[ "$PHASE" = "Succeeded" ]
