#!/bin/bash
set -euo pipefail

REPO="${REPO:-rickmcgeer/jupyter-ai-image}"
TAG="${1:-${TAG:-$(date +%Y.%m.%d)}}"
PUSH="${PUSH:-1}"
# Defaults to the host's native architecture (fast, no emulation) - set
# PLATFORM=linux/amd64 to cross-build for a real GKE cluster (standard node
# pools are amd64), or PLATFORM=linux/amd64,linux/arm64 for a multi-arch
# push. Cross-building needs Docker Desktop's QEMU emulation, so it's slower.
PLATFORM="${PLATFORM:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PLATFORM_ARGS=()
if [[ -n "$PLATFORM" ]]; then
  PLATFORM_ARGS=(--platform "$PLATFORM")
fi

# Build context is the parent directory so the Dockerfile can COPY in the
# sibling ai-tools-launcher repo; -f points back at this repo's Dockerfile.
docker build \
  "${PLATFORM_ARGS[@]}" \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -f Dockerfile -t "$REPO:$TAG" -t "$REPO:latest" ..

if [[ "$PUSH" == "1" || "$PUSH" == "true" ]]; then
  docker push "$REPO:$TAG"
  docker push "$REPO:latest"
  echo "Done! Pushed $REPO:$TAG and $REPO:latest"
else
  echo "Done! Built $REPO:$TAG and $REPO:latest"
fi
