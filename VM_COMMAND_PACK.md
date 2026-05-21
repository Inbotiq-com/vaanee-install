# Vaanee Command Pack (VM Window)

Copy-paste pack for deployment and recovery.

## 1) Standard Deploy
```bash
cd ~/vaanee
sudo docker compose pull vaanee-frontend vaanee-backend vaanee-webhook vaanee-checkin
sudo docker compose up -d --force-recreate vaanee-frontend vaanee-backend vaanee-webhook vaanee-checkin
sleep 40
sudo docker compose ps
curl -I https://<your-domain>/health
```

## 2) Rapid Triage
```bash
cd ~/vaanee
sudo docker compose ps
sudo docker compose logs --tail=120 vaanee-backend vaanee-frontend vaanee-webhook vaanee-checkin caddy
```

## 3) Backend Conflict Marker Check
```bash
sudo docker run --rm inbotiqregistry.azurecr.io/vaanee-backend:2026-05-08-fix-login \
  sh -c "sed -n '470,510p' /app/routes/auth.js"
```

## 4) Healthcheck Detail Inspect
```bash
sudo docker inspect vaanee-frontend --format='{{json .State.Health}}'
sudo docker inspect vaanee-checkin --format='{{json .State.Health}}'
sudo docker inspect vaanee-backend --format='{{json .State.Health}}'
```

## 5) Backend-only Recreate
```bash
cd ~/vaanee
sudo docker compose pull vaanee-backend
sudo docker compose up -d --force-recreate vaanee-backend
sudo docker compose logs --tail=150 vaanee-backend
```

## 6) Frontend + Checkin Recreate
```bash
cd ~/vaanee
sudo docker compose up -d --force-recreate vaanee-frontend vaanee-checkin
sudo docker compose ps
sudo docker compose logs --tail=120 vaanee-frontend
```

## 7) Evidence Snapshot
```bash
cd ~/vaanee
sudo docker compose ps
sudo docker compose logs --tail=200 vaanee-backend vaanee-frontend vaanee-webhook vaanee-checkin caddy
curl -I https://<your-domain>/health
```

## 8) Known Frontend Runtime Mismatch Workaround
When logs show `Failed to find Server Action` or `Unexpected end of form`:
1. Open app in incognito/private window.
2. Clear site data for the domain.
3. Hard refresh (`Ctrl+Shift+R`).
4. Retry login and form actions.
