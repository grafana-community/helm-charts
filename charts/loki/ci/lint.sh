#!/usr/bin/env bash

make helm-schema HELM_CHART=loki

if ! git diff "$GITHUB_SHA" --color=always --exit-code; then
  echo "Please run 'make helm-schema HELM_CHART=loki' to fix the linting errors."
  exit 1
fi
