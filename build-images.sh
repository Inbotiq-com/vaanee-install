#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Build + push the Vaanee on-prem image set to ACR (audit BUILD-01/BUILD-02).
#
# Uses `az acr build`, which uploads the build context and builds CLOUD-SIDE in
# ACR Tasks — no local Docker daemon required. Run by the Inbotiq release team,
# NOT by customers.
#
# All three services are built from the SAME tag so the on-prem fleet always runs
# one tested, reproducible set (previously: backend on a one-off 'fix-login' tag,
# webhook/frontend on the moving 'qa' tag).
#
# Prereqs:
#   az login                      # account with push rights to the registry
#   the three repos checked out on branch `vaanee-onpremise`:
#       AI_Webhook/  inbotiq-backend/  inbotiq-frontend/
#
# Usage:
#   ONPREM_IMAGE_TAG=2026-06-03-onprem ./build-images.sh /path/to/src-root
#   # then set the SAME tag in lib/config.sh (ONPREM_IMAGE_TAG) and re-run install.
# ---------------------------------------------------------------------------
set -euo pipefail

REGISTRY_NAME="${REGISTRY_NAME:-inbotiqregistry}"
TAG="${ONPREM_IMAGE_TAG:-2026-06-03-onprem}"
SRC_ROOT="${1:-.}"

build() {
    local repo="$1" image="$2"
    if [ ! -d "$SRC_ROOT/$repo" ]; then
        echo "ERROR: $SRC_ROOT/$repo not found" >&2
        exit 1
    fi
    echo "==> building $image:$TAG from $SRC_ROOT/$repo"
    az acr build --registry "$REGISTRY_NAME" --image "$image:$TAG" "$SRC_ROOT/$repo"
}

build AI_Webhook       vaanee-webhook
build inbotiq-backend  vaanee-backend
build inbotiq-frontend vaanee-frontend

echo ""
echo "Built and pushed (tag: $TAG):"
echo "  $REGISTRY_NAME.azurecr.io/vaanee-webhook:$TAG"
echo "  $REGISTRY_NAME.azurecr.io/vaanee-backend:$TAG"
echo "  $REGISTRY_NAME.azurecr.io/vaanee-frontend:$TAG"
echo ""
echo "Next: set ONPREM_IMAGE_TAG=$TAG in vaanee-install/lib/config.sh, then install."
