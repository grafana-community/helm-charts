#!/usr/bin/env bash

set -euo pipefail

make helm-schema HELM_CHART=grafana-mcp

# Make a schema that was generated but never committed show up in the diff.
git add --intent-to-add charts/grafana-mcp/values.schema.json

if ! git diff "$GITHUB_SHA" --color=always --exit-code; then
  echo "Please run 'make helm-schema HELM_CHART=grafana-mcp' to fix the linting errors."
  exit 1
fi
