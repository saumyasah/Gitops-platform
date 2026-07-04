#!/usr/bin/env bash
#
# Renders the fully-built manifests for two overlays and diffs them, so a
# reviewer can see exactly what a promotion PR will change on the cluster
# before approving it - not just the one-line kustomization.yaml diff.
#
# Usage: ./diff-preview.sh <from-env> <to-env>
#
set -euo pipefail

FROM_ENV="${1:?Usage: $0 <from-env> <to-env>}"
TO_ENV="${2:?Usage: $0 <from-env> <to-env>}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

echo ">> Building manifests for ${FROM_ENV}..."
kubectl kustomize "${REPO_ROOT}/overlays/${FROM_ENV}" > "/tmp/${FROM_ENV}-rendered.yaml"

echo ">> Building manifests for ${TO_ENV}..."
kubectl kustomize "${REPO_ROOT}/overlays/${TO_ENV}" > "/tmp/${TO_ENV}-rendered.yaml"

echo ">> Diff (${TO_ENV} as currently deployed  vs.  what promoting ${FROM_ENV} would produce):"
diff --color=always -u "/tmp/${TO_ENV}-rendered.yaml" "/tmp/${FROM_ENV}-rendered.yaml" || true
