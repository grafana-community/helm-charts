#!/usr/bin/env bash

set -euo pipefail

make helm-schema HELM_CHART=grafana

# Make a schema that was generated but never committed show up in the diff.
git add --intent-to-add charts/grafana/values.schema.json

if ! git diff "$GITHUB_SHA" --color=always --exit-code; then
  echo "Please run 'make helm-schema HELM_CHART=grafana' to fix the linting errors."
  exit 1
fi
