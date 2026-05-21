# Vaanee On-Prem VM Recovery Runbook

## Purpose
This runbook defines the production recovery flow for Vaanee on-prem VMs after failed deployments, restart loops, or post-release instability.

## Scope
Applies to Docker Compose deployments under `~/vaanee`:
- `vaanee-backend`
- `vaanee-frontend`
- `vaanee-webhook`
- `vaanee-checkin`
- `caddy`

## Recovery Goals
- Restore public health endpoint to HTTP `200`.
- Stabilize `vaanee-backend` and `vaanee-webhook`.
- Ensure frontend is reachable and login flow is usable.

## 1. Preconditions
1. VM SSH access is available.
2. Operator has `sudo` access.
3. Deployment directory exists at `~/vaanee`.
4. Required image tags are already pushed to ACR.

## 2. Initial Triage (Read-only)
```bash
cd ~/vaanee
sudo docker compose ps
sudo docker compose logs --tail=120 vaanee-backend vaanee-frontend vaanee-webhook vaanee-checkin caddy
curl -I https://<your-domain>/health
```

Decision:
- If `/health` is `200` and no restart loops are visible, stop.
- Else continue to controlled refresh.

## 3. Controlled Refresh
### 3.1 Pull target images
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

## 4. Validation Gates
### Gate A: Public health
```bash
curl -I https://<your-domain>/health
```
Pass: HTTP `200`.

### Gate B: Backend liveness
```bash
cd ~/vaanee
sudo docker compose logs --tail=150 vaanee-backend
```
Pass:
- No restart loop.
- No syntax/runtime fatal errors.
- `/health` returns `200` in backend logs.

### Gate C: Webhook liveness
```bash
cd ~/vaanee
sudo docker compose logs --tail=120 vaanee-webhook
```
Pass:
- Process remains up.
- No fatal startup exceptions.

### Gate D: Frontend liveness
```bash
cd ~/vaanee
sudo docker compose logs --tail=120 vaanee-frontend
```
Pass:
- No container crash loop.
- No repeated startup fatal exceptions.

## 5. Known Failure Patterns
### 5.1 Backend syntax crash (`Unexpected token '<<'`)
Cause: merge conflict markers shipped in backend image.

Validate image content:
```bash
sudo docker run --rm inbotiqregistry.azurecr.io/vaanee-backend:2026-05-08-fix-login \
  sh -c "sed -n '470,510p' /app/routes/auth.js"
```

If conflict markers exist:
1. Rebuild and push corrected backend image.
2. Re-run section 3 and section 4.

### 5.2 Frontend Server Action mismatch after deploy
Symptoms:
- `Failed to find Server Action`
- `Unexpected end of form`
- `Cannot write headers after they are sent to the client`

Mitigation sequence:
1. Open app in incognito or clear site data for the domain.
2. Hard refresh (`Ctrl+Shift+R`).
3. Re-login and retry form actions.
4. If still reproducible for new sessions, collect frontend logs and create a code-level fix ticket.

### 5.3 Healthcheck false negatives
If service appears functional but Docker marks unhealthy:
```bash
sudo docker inspect vaanee-frontend --format='{{json .State.Health}}'
sudo docker inspect vaanee-checkin --format='{{json .State.Health}}'
```

Action:
- Keep service status separate from healthcheck status in incident notes.
- Update healthcheck command/interval in next compose/image revision.

## 6. Rollback
If recovery fails:
1. Select last known-good image tags.
2. Pin tags in `docker-compose.yml`.
3. Redeploy:
```bash
cd ~/vaanee
sudo docker compose pull
sudo docker compose up -d --force-recreate
```
4. Re-run validation gates.

## 7. Evidence Collection
Capture:
- `sudo docker compose ps`
- `sudo docker compose logs --tail=200 ...` for impacted services
- `curl -I https://<your-domain>/health`
- `docker inspect ...State.Health` outputs where relevant
- deployed image tags and digests

## 8. Exit Criteria
Recovery is complete only when all are true:
1. `/health` returns HTTP `200`.
2. `vaanee-backend` is healthy and stable.
3. `vaanee-webhook` is stable.
4. Frontend is reachable and login flow works.
5. Incident evidence is documented.
