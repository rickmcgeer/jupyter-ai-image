#!/bin/bash
set -euo pipefail

REPO="${REPO:-rickmcgeer/jupyter-ai-image}"
TAG="${1:-${TAG:-$(date +%Y.%m.%d)}}"
PUSH="${PUSH:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Pulls an amd64-only Node.js binary, so always target linux/amd64 regardless
# of host architecture.
docker build --platform linux/amd64 \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -t "$REPO:$TAG" -t "$REPO:latest" .

if [[ "$PUSH" == "1" || "$PUSH" == "true" ]]; then
  docker push "$REPO:$TAG"
  docker push "$REPO:latest"
  echo "Done! Pushed $REPO:$TAG and $REPO:latest"
else
  echo "Done! Built $REPO:$TAG and $REPO:latest"
fi
