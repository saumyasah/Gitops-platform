#!/usr/bin/env bash
#
# Promotes the image tag currently deployed in <from-env> to <to-env> by
# opening a PR that updates the target overlay's kustomization.yaml.
# Merging the PR is the deployment - no direct kubectl/ArgoCD CLI access
# needed to ship a promotion.
#
# Usage: ./promote.sh <from-env> <to-env>
# Example: ./promote.sh dev staging
#
set -euo pipefail

FROM_ENV="${1:?Usage: $0 <from-env> <to-env>}"
TO_ENV="${2:?Usage: $0 <from-env> <to-env>}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

FROM_KUSTOMIZATION="${REPO_ROOT}/overlays/${FROM_ENV}/kustomization.yaml"
TO_KUSTOMIZATION="${REPO_ROOT}/overlays/${TO_ENV}/kustomization.yaml"

if [[ ! -f "$FROM_KUSTOMIZATION" || ! -f "$TO_KUSTOMIZATION" ]]; then
  echo "ERROR: overlay not found for '${FROM_ENV}' or '${TO_ENV}'." >&2
  exit 1
fi

CURRENT_TAG=$(grep -A1 "newTag" "$FROM_KUSTOMIZATION" | grep "newTag" | awk '{print $2}')
echo ">> Promoting image tag '${CURRENT_TAG}' from ${FROM_ENV} to ${TO_ENV}..."

BRANCH="promote-${FROM_ENV}-to-${TO_ENV}-$(date +%Y%m%d-%H%M%S)"
git checkout -b "${BRANCH}"

sed -i.bak "s/newTag: .*/newTag: ${CURRENT_TAG}/" "$TO_KUSTOMIZATION"
rm -f "${TO_KUSTOMIZATION}.bak"

git add "$TO_KUSTOMIZATION"
git commit -m "Promote ${FROM_ENV} -> ${TO_ENV}: image tag ${CURRENT_TAG}"
git push -u origin "${BRANCH}"

if command -v gh &>/dev/null; then
  gh pr create \
    --title "Promote ${FROM_ENV} -> ${TO_ENV}: ${CURRENT_TAG}" \
    --body "Promotes image tag \`${CURRENT_TAG}\` from \`${FROM_ENV}\` to \`${TO_ENV}\`.

Run \`./scripts/diff-preview.sh ${FROM_ENV} ${TO_ENV}\` locally to review the exact manifest diff before approving." \
    --base main --head "${BRANCH}"
else
  echo ">> gh CLI not found. Push complete - open a PR manually for branch '${BRANCH}'."
fi
