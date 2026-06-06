#!/usr/bin/env bash
# ===========================================================================
# Vaanee on-prem SEAMLESS AUTO-UPDATER (HARDEN-D)
# ---------------------------------------------------------------------------
# Polls the central check-in for the image tag the platform owner wants this VM
# to run. If it differs from what's running, it pulls the new images, recreates
# the stack, health-checks the webhook, and ROLLS BACK on failure — then reports
# the result to central (POST /api/vaanee/updated). Idempotent + safe on a timer.
#
# Installed by vaanee-install into $VAANEE_DIR and run by the vaanee-update.timer
# systemd unit (default every 15 min). The platform owner triggers a fleet update
# simply by building + pushing a new image and setting VAANEE_VM_IMAGE_TAG on the
# central backend — every VM converges on the next poll.
# ===========================================================================
set -uo pipefail

VAANEE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE="$VAANEE_DIR/docker-compose.yml"
LOG="$VAANEE_DIR/vaanee-update.log"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }

[ -f "$COMPOSE" ] || { log "no compose at $COMPOSE; abort"; exit 0; }
# Load env (VAANEE_API_KEY / INBOTIQ_API / VAANEE_MAIN_SERVER_URL / INSTANCE_ID).
if [ -f "$VAANEE_DIR/.env" ]; then set -a; . "$VAANEE_DIR/.env"; set +a; fi

API="${INBOTIQ_API:-}"
[ -n "${VAANEE_MAIN_SERVER_URL:-}" ] && API="${VAANEE_MAIN_SERVER_URL%/}/api"
KEY="${VAANEE_API_KEY:-}"
[ -z "$API" ] && { log "no INBOTIQ_API; abort"; exit 0; }
[ -z "$KEY" ] && { log "no VAANEE_API_KEY; abort"; exit 0; }
API="${API%/}"

dc() { docker compose -f "$COMPOSE" "$@"; }

# 1) Ask central what tag we should run.
RESP=$(curl -fsS --max-time 25 -X POST "$API/vaanee/check-in" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d "{\"instance_id\":\"${INSTANCE_ID:-vaanee-docker-01}\",\"version\":\"${VAANEE_VERSION:-1.0.0}\"}" 2>/dev/null) \
  || { log "check-in failed"; exit 0; }
WANT=$(printf '%s' "$RESP" | grep -oE '"image_tag":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//')
[ -z "$WANT" ] && { log "no image_tag in check-in response; nothing to do"; exit 0; }

# 2) What are we running now?
CUR=$(grep -oE 'vaanee-webhook:[^"[:space:]]+' "$COMPOSE" | head -1 | sed 's/.*://')
[ "$WANT" = "$CUR" ] && exit 0   # up to date — quiet no-op

log "UPDATE requested: $CUR -> $WANT"
cp "$COMPOSE" "$COMPOSE.rollback"

report() { # <success-bool> <message>
  curl -fsS --max-time 20 -X POST "$API/vaanee/updated" \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d "{\"from_tag\":\"$CUR\",\"to_tag\":\"$WANT\",\"success\":$1,\"message\":\"$2\"}" >/dev/null 2>&1 || true
}
rollback() {
  log "ROLLBACK -> $CUR"
  cp "$COMPOSE.rollback" "$COMPOSE"
  dc pull >>"$LOG" 2>&1; dc up -d >>"$LOG" 2>&1
  report false "$1; rolled back to $CUR"
  exit 1
}

# 3) Refresh the ACR pull token (licence-key gated) and log in.
CREDS=$(curl -fsS --max-time 25 -H "Authorization: Bearer $KEY" "$API/vaanee/registry-credentials" 2>/dev/null)
RG=$(printf '%s' "$CREDS" | grep -oE '"registry":"[^"]*"' | sed 's/.*:"//;s/"$//')
RU=$(printf '%s' "$CREDS" | grep -oE '"username":"[^"]*"' | sed 's/.*:"//;s/"$//')
RP=$(printf '%s' "$CREDS" | grep -oE '"password":"[^"]*"' | sed 's/.*:"//;s/"$//')
[ -n "$RG" ] && [ -n "$RP" ] && printf '%s' "$RP" | docker login "$RG" -u "${RU:-vaanee}" --password-stdin >>"$LOG" 2>&1

# 4) Point all three images at the new tag, pull, recreate.
sed -i -E "s#(vaanee-(webhook|backend|frontend)):[^\"[:space:]]+#\1:$WANT#g" "$COMPOSE"
dc pull >>"$LOG" 2>&1 || rollback "image pull failed"
dc up -d >>"$LOG" 2>&1 || rollback "compose up failed"

# 5) Health-check the webhook (the call path). Up to ~60s.
ok=0
for _ in $(seq 1 12); do
  sleep 5
  if docker exec vaanee-webhook curl -fsS http://127.0.0.1:8000/ >/dev/null 2>&1; then ok=1; break; fi
done
[ "$ok" = 1 ] || rollback "health-check failed after update"

log "UPDATE OK -> $WANT"
rm -f "$COMPOSE.rollback"
report true "updated $CUR -> $WANT"
