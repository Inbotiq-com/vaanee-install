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

# Single-flight: the systemd timer could fire while a previous run is still
# pulling/recreating. Take a non-blocking lock; if held, skip this tick.
exec 9>"$VAANEE_DIR/.vaanee-update.lock" 2>/dev/null || true
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || { log "another updater run in progress; skipping"; exit 0; }
fi

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
CUR=$(grep -oE 'inbotiqregistry[^"[:space:]]*vaanee-webhook:[^"[:space:]]+' "$COMPOSE" | head -1 | sed 's/.*://')
[ "$WANT" = "$CUR" ] && { docker exec vaanee-webhook rm -f /app/cache/update_requested 2>/dev/null || true; exit 0; }  # up to date

# A new tag is published. Apply when the CLIENT opts in (the dashboard "Update now"
# button writes /app/cache/update_requested) OR the mandatory deadline has passed
# (compulsory). Otherwise leave the dashboard notification up and wait.
MAND=$(printf '%s' "$RESP" | grep -oE '"update_mandatory_after":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//')
FLAG=0; docker exec vaanee-webhook test -f /app/cache/update_requested 2>/dev/null && FLAG=1
DUE=0
if [ -n "$MAND" ]; then
  ME=$(date -d "$MAND" +%s 2>/dev/null || echo 0); NOW=$(date +%s)
  [ "$ME" != "0" ] && [ "$NOW" -ge "$ME" ] && DUE=1
fi

# Canary (#4): only apply if this VM is within the published rollout %, unless the
# update has become mandatory.
ELIGIBLE=$(printf '%s' "$RESP" | grep -oE '"update_eligible":(true|false)' | head -1 | grep -oE 'true|false')
if [ "$ELIGIBLE" = "false" ] && [ "$DUE" != "1" ]; then
  log "update $CUR -> $WANT published; this VM not in the rollout yet; waiting"
  exit 0
fi

if [ "$FLAG" != "1" ] && [ "$DUE" != "1" ]; then
  log "update $CUR -> $WANT available; awaiting client opt-in or mandatory deadline ($MAND)"
  exit 0
fi

# Don't interrupt active calls (#5) unless the update is now mandatory.
if [ "$DUE" != "1" ]; then
  ACTIVE=$(docker exec vaanee-webhook python3 -c "
import os
def _n():
    try:
        import psycopg2
        c = psycopg2.connect(os.environ['DATABASE_URL'], connect_timeout=5)
        cur = c.cursor(); cur.execute(\"SELECT COUNT(*) FROM call_session WHERE ended_at IS NULL AND started_at > NOW() - INTERVAL '3 hours'\")
        n = int(cur.fetchone()[0]); c.close(); return n
    except Exception:
        return 0
print(_n())
" 2>/dev/null || echo 0)
  if [ "${ACTIVE:-0}" -gt 0 ]; then
    log "deferring update $CUR -> $WANT: $ACTIVE active call(s) in progress"
    exit 0
  fi
fi

log "UPDATE requested: $CUR -> $WANT (flag=$FLAG mandatory_due=$DUE eligible=$ELIGIBLE)"
cp "$COMPOSE" "$COMPOSE.rollback"

report() { # <success-bool> <message>
  curl -fsS --max-time 20 -X POST "$API/vaanee/updated" \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d "{\"from_tag\":\"$CUR\",\"to_tag\":\"$WANT\",\"success\":$1,\"message\":\"$2\"}" >/dev/null 2>&1 || true
}
# Persist a LOCAL failure marker on the shared cache volume so the dashboard can show a
# red "update failed / try again" banner (reload-proof, server-driven). Increments a
# count across consecutive failures; cleared on the next successful update. Message is
# passed via env to avoid any shell-quoting issues.
mark_failure() { # <message>
  docker exec -e FAILMSG="$1" -e FAILTAG="$WANT" vaanee-webhook python3 -c "
import json,os,time
p='/app/cache/update_failed.json'
try:
    d=json.load(open(p))
except Exception:
    d={}
d['count']=int(d.get('count',0))+1
d['message']=os.environ.get('FAILMSG','update failed')
d['to_tag']=os.environ.get('FAILTAG','')
d['at']=int(time.time())
json.dump(d, open(p,'w'))
" 2>/dev/null || true
}
rollback() {
  log "ROLLBACK -> $CUR"
  cp "$COMPOSE.rollback" "$COMPOSE"
  dc pull >>"$LOG" 2>&1; dc up -d >>"$LOG" 2>&1
  mark_failure "$1"
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
sed -i -E "s#(inbotiqregistry\.azurecr\.io/vaanee-(webhook|backend|frontend)):[^\"[:space:]]+#\1:$WANT#g" "$COMPOSE"
# Keep the backend's advertised running tag in sync (in compose AND .env, wherever
# it lives) so the dashboard's update notification clears once the new images are live.
sed -i -E "s#(VAANEE_RUNNING_IMAGE_TAG=)[^\"[:space:]]+#\1$WANT#g" "$COMPOSE"
[ -f "$VAANEE_DIR/.env" ] && sed -i -E "s#(VAANEE_RUNNING_IMAGE_TAG=)[^\"[:space:]]+#\1$WANT#g" "$VAANEE_DIR/.env"
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
docker exec vaanee-webhook rm -f /app/cache/update_requested 2>/dev/null || true
docker exec vaanee-webhook rm -f /app/cache/update_failed.json 2>/dev/null || true   # clear any prior failure marker
report true "updated $CUR -> $WANT"
