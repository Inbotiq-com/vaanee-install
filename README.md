# Vaanee On-Premise Installer

Production-ready one-time installer for Vaanee customer deployments.

This installer:
- Validates host requirements
- Installs/configures Docker (if missing)
- Generates deployment files (`.env`, `docker-compose.yml`)
- Runs `migrate.sql` against your PostgreSQL database
- Bootstraps organization and primary user from Inbotiq
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

Run on your target Linux server:

```bash
curl -fsSL https://get.vaanee.io/install.sh | bash
```

Installer will prompt for:
- `VAANEE_API_KEY`
- domain (for HTTPS)
- `DATABASE_URL`
- admin email (Let's Encrypt notifications)

## 3. What Gets Created

Default deployment directory:

```bash
$HOME/vaanee
```

Important files:
- `.env`
- `docker-compose.yml`
- `migrate.sql`

## 4. Database Migration Behavior

Migration is fail-fast and production-safe:
- `psql` runs with `ON_ERROR_STOP=1`
- On SQL failure, installer exits immediately
- No silent migration success

Note:
- Control-plane tracking tables are intentionally not created in customer DB:
  - `vaanee_package_licences`
  - `vaanee_package_events`
  - `vaanee_request_logs`

## 5. Post-Install Verification

### A) Containers are up

```bash
cd ~/vaanee
sudo docker compose ps
```

Expected: all Vaanee services in `Up` state.

### B) Health/log sanity

```bash
sudo docker compose logs --tail=200
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

### D) Verify required bootstrap data exists

```sql
SELECT COUNT(*) FROM organizations;
SELECT COUNT(*) FROM users;
```

Expected: at least one organization/user for first successful bootstrap.

## 6. Re-run / Upgrade Flow

Safe re-run pattern:

```bash
cd ~/vaanee
curl -fsSL https://raw.githubusercontent.com/Inbotiq-com/vaanee-install/main/install.sh -o install.sh
bash install.sh
```

Migration uses `IF NOT EXISTS`/idempotent patterns, so reruns are supported.

## 7. Troubleshooting

### Migration failed
- Re-run manually to see exact SQL line:

```bash
psql "$DATABASE_URL" -f "$HOME/vaanee/migrate.sql" -v ON_ERROR_STOP=1
```

### Bootstrap skipped
- Cause: API key invalid, API unreachable, or response parse failure
- Verify key format starts with `vaan_live_`
- Verify outbound connectivity from server to Inbotiq API

### SSL/Domain issues
- Confirm domain A record points to correct public IP
- Ensure ports `80/443` are open in firewall/security group

## 8. Security Notes

- Treat `DATABASE_URL` and `.env` as secrets
- Restrict server access to trusted admins only
- Rotate credentials if exposed
- Keep host patched and Docker updated

## 9. Rollback (Emergency)

Stop services:

```bash
cd ~/vaanee
sudo docker compose down
```

Restore database from backup/snapshot as per your DB policy.

## 10. Support Checklist (Share When Raising Issue)

- OS/version
- Installer timestamp
- `docker compose ps` output
- Last 200 lines of `docker compose logs`
- Exact migration error line/message
- Whether bootstrap step succeeded