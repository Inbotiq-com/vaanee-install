# Vaanee On-Premise Installer

Production-ready installer for Vaanee customer deployments.

This installer:
- Validates host requirements
- Installs/configures Docker (if missing)
- Generates deployment files (`.env`, `docker-compose.yml`, `Caddyfile`)
- Downloads and runs modular SQL migrations on client PostgreSQL
- Starts Vaanee services

## 1. Prerequisites

- OS: Ubuntu 20.04+ (Linux)
- CPU: 2+ cores recommended
- RAM: 4 GB minimum recommended
- Open ports: `80`, `443`
- Domain with DNS A record pointing to server
- Existing PostgreSQL database
- Vaanee API key (`vaan_live_...`)
- `sudo` access on server

## 2. Quick Install

Run on target Linux server:

```bash
curl -fsSL https://raw.githubusercontent.com/Inbotiq-com/vaanee-install/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

Installer prompts for:
- `VAANEE_API_KEY`
- domain (for HTTPS)
- `DATABASE_URL`
- admin email (Let's Encrypt notifications)

Optional endpoint override (QA/internal testing only):

```bash
INBOTIQ_API="https://inbotiq-backend-qa.azurewebsites.net/api" ./install.sh
```

Default is production endpoint.

## 2b. Local Testing (no public domain / SSL)

To test the full stack on a machine without a public domain — e.g. a VirtualBox VM
on your LAN — set `VAANEE_LOCAL_TLS=1`. This makes Caddy issue a **self-signed**
certificate (via `tls internal`) instead of Let's Encrypt, which cannot validate a
non-public domain. It also points the post-install health check at `localhost`.

```bash
VAANEE_LOCAL_TLS=1 bash install.sh
```

At the domain prompt, enter any name you like (e.g. `vaanee.local`). After install:

1. On the **machine running the browser**, map that domain to the VM's LAN IP in the
   hosts file (`/etc/hosts` on Linux/macOS, `C:\Windows\System32\drivers\etc\hosts`
   on Windows), e.g.:

   ```text
   192.168.1.18   vaanee.local
   ```

2. Browse to `https://vaanee.local` and accept the self-signed certificate warning.

Verify on the VM:

```bash
cd ~/vaanee
sudo docker compose ps
curl -k https://localhost/health    # expect 200
```

> `VAANEE_LOCAL_TLS` has **no effect** on normal installs — leave it unset for any
> real deployment so Let's Encrypt issues a trusted certificate as usual.

## 3. Repository Structure

```text
vaanee-install/
  install.sh
  lib/
    config.sh
    ui.sh
    steps.sh
    steps/
      system.sh
      input_and_validation.sh
      files_and_migrations.sh
      runtime.sh
  migrate.sql
  migrations/
    001_extensions.sql
    002_agents_and_flows.sql
    003_knowledge_base.sql
    004_calls_runtime.sql
    005_pronunciation_and_campaigns.sql
    006_indexes_and_finalize.sql
```

`install.sh` is a thin runner. It auto-fetches missing `lib/` step files plus `migrate.sql` and `migrations/*.sql` when executed from a fresh host.

## 4. What Gets Created On Server

Default deployment directory:

```bash
$HOME/vaanee
```

Important files:
- `.env`
- `docker-compose.yml`
- `Caddyfile`
- `migrate.sql`
- `migrations/*.sql`

## 5. Database Migration Behavior

Migration is fail-fast and idempotent:
- `psql` runs with `ON_ERROR_STOP=1`
- on SQL error, installer exits immediately
- schema uses `IF NOT EXISTS` and safe `ALTER` patterns for reruns

The installer also validates pgvector availability before migration.

Control-plane/billing tables are intentionally NOT created in client DB:
- `vaanee_package_licences`
- `vaanee_package_events`
- `vaanee_request_logs`

## 6. Post-Install Verification

### A) Containers are up

```bash
cd ~/vaanee
sudo docker compose ps
```

Expected services:
- `caddy`
- `vaanee-backend`
- `vaanee-webhook`
- `vaanee-checkin`
- `vaanee-frontend`

### B) Health/log sanity

```bash
cd ~/vaanee
sudo docker compose logs --tail=200 vaanee-backend vaanee-webhook vaanee-checkin caddy
```

Check there are no startup crash loops or DB connection errors.

### C) Verify excluded control-plane tables are NOT present

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'vaanee_package_licences',
    'vaanee_package_events',
    'vaanee_request_logs'
  );
```

Expected: `0 rows`.

## 7. Re-run / Upgrade Flow

Safe rerun:

```bash
cd ~
curl -fsSL https://raw.githubusercontent.com/Inbotiq-com/vaanee-install/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

## 8. Troubleshooting

### API key validation returns `402 expired`
- Endpoint/environment mismatch (QA vs prod) OR expired backend subscription record.
- Validate check-in directly:

```bash
curl -i -X POST "$INBOTIQ_API/vaanee/check-in" \
  -H "Authorization: Bearer <VAANEE_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"instance_id":"manual-test","version":"1.0.0"}'
```

### Migration fails with pgvector allowlist error (Azure PostgreSQL)
- Enable `vector` in Azure PostgreSQL server parameter `azure.extensions`.

### Database name appears as `...&keepalives=... does not exist`
- Incorrect query delimiter in `DATABASE_URL`.
- Correct format should include `?` before query params.

### Service name confusion in logs
- Use compose service names (`caddy`, `vaanee-backend`, etc.), not container names.

## 9. Security Notes

- Treat `DATABASE_URL` and `.env` as secrets
- Restrict server access to trusted admins only
- Rotate credentials if exposed
- Keep host patched and Docker updated

## 10. Rollback (Emergency)

```bash
cd ~/vaanee
sudo docker compose down
```

Restore database from backup/snapshot as per DB policy.

## 11. Support Checklist

When raising an issue, share:
- OS/version
- installer timestamp
- `docker compose ps` output
- last 200 lines of `docker compose logs`
- exact migration error line/message
- API check-in response (`$INBOTIQ_API/vaanee/check-in`)

## 12. Operational Docs

- `VM_RECOVERY_RUNBOOK.md`: production recovery SOP for restart loops and 502 incidents.
- `VM_EXECUTION_CHECKLIST.md`: step-by-step deployment validation checklist for VM windows.
- `VM_COMMAND_PACK.md`: copy-paste command bundle for deploy/triage/recovery.
