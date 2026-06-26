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
# 2026-06-14-onprem: full build of all 3 from vaanee-onpremise — adds campaign
# management (Activate/Deactivate/Delete buttons + campaign delete API endpoint)
# and the Recent-calls column-filter UX, on top of 2026-06-13-onprem (VoxCPM
# neural voices + concurrency leak fix + org-concurrency-aware Plivo campaigns +
# campaign-UI). This is the tag published to the fleet via the central
# auto-update channel (check-in already serves it: eligible + mandatory 2026-06-17).
# 2026-06-15-onprem: rebuild of all 3 from vaanee-onpremise HEAD — backend adds
# the KB per-page vector purge + sitemap-delete cascade and KB refresh-flow rework;
# webhook adds per-node intent extraction + function-response context storage (on
# top of the VoxCPM voice_mode/describe/clone fixes); frontend unchanged from
# 2026-06-14-onprem (retagged for a consistent fleet set).
# NOTE (2026-06-17): this is now only a FALLBACK. validate_api_key() adopts the
# central-published fleet image_tag from the check-in response when central is
# reachable, so a normal install ignores this value. It is used only for offline /
# unreachable-central installs, or if central returns no image_tag. You no longer
# need to bump it every release — publish the tag to central (vaanee_fleet_config /
# admin "Publish Update") instead, which covers both new installs and existing VMs.
# 2026-06-25: bumped the fallback to 2026-06-25-onprem so even an OFFLINE / no-image_tag
# install starts with the flow first-node greeting fix (stateful/flow agents open the
# call via the flow's first node, not the static welcome_message) instead of the old
# 2026-06-15-onprem image; online installs already get this from central.
ONPREM_IMAGE_TAG="${ONPREM_IMAGE_TAG:-2026-06-25-onprem}"

# PRODUCTION central (2026-06-26): main branch serves prod-created VMs. This is the
# live prod backend App Service `Backend` in RG `Inbotiq`. VAANEE_MAIN_SERVER_URL and
# the check-in + preview-proxy target all derive from this. The fleet image tag is NOT
# baked here — validate_api_key() adopts the tag prod's vaanee_fleet_config publishes at
# check-in (ONPREM_IMAGE_TAG is only the offline fallback).
# NOTE: the old `inbotiq-backend.azurewebsites.net` host (named in this comment pre-split)
# has stale/dead DNS — do NOT use it. The QA installer lives on the `qa` branch and keeps
# INBOTIQ_API = inbotiq-backend-qa for QA-created VMs.
INBOTIQ_API="${INBOTIQ_API:-https://backend-g3cubwe7fuf7bze7.centralindia-01.azurewebsites.net/api}"
