VAANEE_DIR="$HOME/vaanee"
REGISTRY="${REGISTRY:-inbotiqregistry.azurecr.io}"
REGISTRY_USER="${REGISTRY_USER:-vaanee-client-pull}"

# ACR pull token — provided per-install via environment, NOT baked into source.
# The previously-hardcoded shared token was a committed secret (audit SEC-03) and
# is removed. Generate a scoped, per-customer ACR token and pass it at install:
#     REGISTRY_PASS='<token>' bash install.sh
# pull_images() fails closed with a clear message if this is empty.
REGISTRY_PASS="${REGISTRY_PASS:-}"

# Single immutable image tag for all on-prem services so backend/webhook/frontend
# always ship as one tested, reproducible set (was mismatched: backend on a
# one-off 'fix-login' tag, others on the moving 'qa' tag — audit BUILD-02).
ONPREM_IMAGE_TAG="${ONPREM_IMAGE_TAG:-2026-06-08-onprem}"

INBOTIQ_API="${INBOTIQ_API:-https://inbotiq-backend-qa.azurewebsites.net/api}"
