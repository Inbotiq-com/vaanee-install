# Vaanee On-Prem VM Recovery Runbook

## Purpose
This runbook standardizes recovery of a Vaanee customer VM after deployment failures, container crash loops, or post-upgrade service instability.

## Scope
Applies to services deployed via `docker compose` under `~/vaanee`:
- `vaanee-backend`
- `vaanee-frontend`
- `vaanee-webhook`
- `vaanee-checkin`
- `caddy`

## Recovery Objectives
- Restore public health endpoint (`/health`) to HTTP `200`.
- Ensure `vaanee-backend` and `vaanee-webhook` are healthy and stable.
- Confirm UI accessibility and login readiness.

---

## 1. Preconditions

1. SSH access to target VM is available.
2. User has `sudo` privileges.
3. Correct deployment directory exists at `~/vaanee`.
4. Required tags are already pushed to ACR.

---

## 2. Initial Triage (Read-Only)

```bash
cd ~/vaanee
sudo docker compose ps
sudo docker compose logs --tail=120 vaanee-backend vaanee-frontend vaanee-webhook vaanee-checkin caddy
curl -I https://<your-domain>/health
```

Decision:
- If `/health` is `200` and no restarts: stop here.
- If services are restarting/unhealthy: continue.

---

## 3. Controlled Service Refresh

### 3.1 Pull latest images

```bash
cd ~/vaanee
sudo docker compose pull vaanee-backend vaanee-frontend vaanee-webhook vaanee-checkin
```

### 3.2 Recreate application services

```bash
cd ~/vaanee
sudo docker compose up -d --force-recreate vaanee-backend vaanee-frontend vaanee-webhook vaanee-checkin
```

### 3.3 Stabilization wait

```bash
sleep 40
sudo docker compose ps
```

---

## 4. Service Validation Gates

### Gate A: Public endpoint

```bash
curl -I https://<your-domain>/health
```

Pass criteria: HTTP `200`.

### Gate B: Backend liveness

```bash
cd ~/vaanee
sudo docker compose logs --tail=150 vaanee-backend
```

Pass criteria:
- No restart loop.
- No syntax/runtime fatal errors.
- `/health` requests return `200` in logs.

### Gate C: Webhook liveness

```bash
cd ~/vaanee
sudo docker compose logs --tail=120 vaanee-webhook
```

Pass criteria:
- Service is up.
- No fatal startup exceptions.

---

## 5. Known Failure Patterns and Actions

### 5.1 Backend syntax crash (`Unexpected token '<<'`)
Cause: merge-conflict markers shipped in image.

Validate image content:
```bash
sudo docker run --rm inbotiqregistry.azurecr.io/vaanee-backend:2026-05-08-fix-login \
  sh -c "sed -n '470,510p' /app/routes/auth.js"
```

If markers exist:
- rebuild/push corrected backend image
- re-run section 3

### 5.2 Frontend “Server Action” mismatch / stale client state
Symptoms in logs:
- `Failed to find Server Action`
- `Unexpected end of form`

Action:
1. Open app in incognito or clear site storage.
2. Hard refresh (`Ctrl+Shift+R`).
3. Login again.

### 5.3 Healthcheck false negatives
If app is functional but service shows unhealthy, capture health details:
```bash
sudo docker inspect vaanee-frontend --format='{{json .State.Health}}'
sudo docker inspect vaanee-checkin --format='{{json .State.Health}}'
```

Then update healthcheck configuration in compose/image revision.

---

## 6. Rollback Procedure (If Recovery Fails)

1. Identify last known good image tags.
2. Pin tags in `docker-compose.yml` (or deployment env).
3. Redeploy:

```bash
cd ~/vaanee
sudo docker compose pull
sudo docker compose up -d --force-recreate
```

4. Re-run Validation Gates (Section 4).

---

## 7. Evidence to Capture for Incident Report

Collect and attach:
- `sudo docker compose ps`
- `sudo docker compose logs --tail=200 ...` for failed services
- `curl -I https://<your-domain>/health`
- Any `docker inspect ...State.Health` outputs
- Exact image tags and digests deployed

---

## 8. Completion Criteria

Recovery is complete only when all below are true:
1. `/health` returns HTTP `200`.
2. `vaanee-backend` is `healthy` and not restarting.
3. `vaanee-webhook` is up and stable.
4. UI is reachable and login flow is usable.
5. Incident evidence is documented.