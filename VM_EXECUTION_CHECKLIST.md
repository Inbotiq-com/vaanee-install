# Vaanee VM Execution Checklist

Use this checklist when VM access is available. Mark each item in order.

## A. Pre-Deployment
- [ ] Confirm branch artifacts are already built and pushed to ACR.
- [ ] Confirm target tags:
  - `inbotiqregistry.azurecr.io/vaanee-frontend:qa`
  - `inbotiqregistry.azurecr.io/vaanee-backend:2026-05-08-fix-login`
- [ ] SSH access works for target VM.
- [ ] `~/vaanee` exists on VM.

## B. Pull and Recreate
```bash
cd ~/vaanee
sudo docker compose pull vaanee-frontend vaanee-backend vaanee-webhook vaanee-checkin
sudo docker compose up -d --force-recreate vaanee-frontend vaanee-backend vaanee-webhook vaanee-checkin
```

- [ ] Pull completed without auth/tag errors.
- [ ] Recreate completed without compose errors.

## C. Stabilization and Health
```bash
sleep 40
cd ~/vaanee
sudo docker compose ps
curl -I https://<your-domain>/health
```

- [ ] `vaanee-backend` healthy.
- [ ] `vaanee-webhook` up and stable.
- [ ] `/health` returns HTTP `200`.

## D. Deep Logs
```bash
cd ~/vaanee
sudo docker compose logs --tail=150 vaanee-backend
sudo docker compose logs --tail=120 vaanee-frontend
sudo docker compose logs --tail=120 vaanee-webhook
sudo docker compose logs --tail=120 vaanee-checkin
```

- [ ] No backend syntax errors.
- [ ] No backend restart loop.
- [ ] Frontend not crash-looping.
- [ ] Webhook receiving health pings.

## E. Functional Smoke
- [ ] Open app URL and verify page load.
- [ ] Login using test credentials.
- [ ] Hit one critical flow (agent/dashboard page).
- [ ] Confirm no 502 from caddy.

## F. If Unhealthy
- [ ] Run `VM_RECOVERY_RUNBOOK.md` section-by-section.
- [ ] Collect incident evidence (`ps`, logs, health response, image digests).

## G. Sign-off
- [ ] Runtime stable for 10+ minutes.
- [ ] No restart counters increasing.
- [ ] Health endpoint still `200`.
- [ ] Deployment evidence shared in handoff note.
