# vaanee-install

## Troubleshooting environment mismatch errors

If an endpoint works in Vaanee cloud/hosted but fails on an on-prem VM, the most common cause is an **environment mismatch** (routing, auth bootstrap, schema, or seeded data).

### A) `GET /api/auth/me` returns `404`

Likely causes:
- The packaged VM build does not expose the same auth route set as hosted.
- Reverse proxy rules are routing `/api/*` differently on this deployment.
- Session/auth middleware is not enabled in this environment.

What to verify:
1. Confirm the running API container actually serves `/api/auth/me`.
2. Confirm nginx/traefik/caddy forwards `/api` to the same backend as hosted.
3. Confirm frontend `API_BASE_URL` (or equivalent) points to the API service that has auth routes.

Quick check:
```bash
curl -i https://<your-domain>/api/auth/me
```

### B) `GET /api/subscriptions/my-subscriptions` returns `403` (`Admin required`)

Likely causes:
- Seeded VM user exists but is not mapped to admin role.
- Role linkage (user/admin/org relationship) was not created during bootstrap.
- Migrations succeeded but role seed logic did not run.

What to verify in Postgres:
```sql
-- check account + role
SELECT id, email, role, organization_id, is_active
FROM admins
WHERE email = '<login-email>';

-- check user/org linkage if login is against users table
SELECT id, email, organization_id, is_active
FROM users
WHERE email = '<login-email>';
```

### C) `GET /api/caller-ai-chatbot/analytics` returns `500`

Likely causes:
- Required analytics/call-history data is missing for this org.
- On-prem schema is behind the backend binary expectations.
- Query assumptions fail due to missing org/user/call records in seeded DB.

What to verify:
1. Run migrations from this repo (`migrate.sql`) against the exact DB used by the running API.
2. Compare row presence for org/user/caller-ai related tables.
3. Inspect API logs to identify failing table/column/join.

Basic schema sanity check:
```bash
psql "$DATABASE_URL" -f migrate.sql
```

## Suggested triage order

1. **Routing parity first** (`/api/auth/me` 404).
2. **Authorization bootstrap next** (`403 Admin required`).
3. **Data/schema parity last** (`analytics` 500).

This ordering avoids chasing data bugs when the deployment path or role mapping is still incorrect.
