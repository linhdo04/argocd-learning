#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: cần kubectl để render Kustomize." >&2
  exit 1
fi

echo "Render Kustomize targets..."
for target in \
  labs/base \
  labs/overlays/dev \
  labs/overlays/staging \
  labs/overlays/prod \
  labs/hooks; do
  echo "  - $target"
  kubectl kustomize "$target" >/dev/null
done

if command -v yamllint >/dev/null 2>&1; then
  echo "Run yamllint..."
  yamllint labs
else
  echo "SKIP: yamllint chưa được cài."
fi

if [[ "${LIVE_SCHEMA_CHECK:-0}" == "1" ]]; then
  echo "Client dry-run cho manifest Argo CD..."
  kubectl apply --dry-run=client --validate=false -f labs/argocd >/dev/null
fi

echo "Validation hoàn tất."
