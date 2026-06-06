write_files() {
    print_step "Writing deployment files"

    mkdir -p "$VAANEE_DIR"
    mkdir -p "$VAANEE_DIR/migrations"
    VAANEE_MAIN_SERVER_URL="${INBOTIQ_API%/api}"

    cat > "$VAANEE_DIR/.env" << EOF
VAANEE_API_KEY=$VAANEE_API_KEY
VAANEE_DOMAIN=$VAANEE_DOMAIN
DATABASE_URL=$DATABASE_URL
ADMIN_EMAIL=$ADMIN_EMAIL
INSTANCE_ID=$(hostname)-$(openssl rand -hex 4)
VAANEE_MAIN_SERVER_URL=$VAANEE_MAIN_SERVER_URL
VAANEE_BASE_URL=$VAANEE_MAIN_SERVER_URL
BASE_URL=$VAANEE_MAIN_SERVER_URL

NODE_ENV=production
PORT=8080
VAANEE_MODE=true
IS_PACKAGED_DEPLOYMENT=true
PUBLIC_BASE_URL=https://$VAANEE_DOMAIN
INTERNAL_API_URL=http://vaanee-backend:8080

NEXT_PUBLIC_API_URL=https://$VAANEE_DOMAIN
NEXT_PUBLIC_BACKEND_URL=https://$VAANEE_DOMAIN
NEXT_PUBLIC_MAIN_APP_URL=https://$VAANEE_DOMAIN
NEXT_PUBLIC_CALLER_AI_BASE_URL=https://$VAANEE_DOMAIN
NEXT_PUBLIC_CALLER_AI_WEBHOOK_URL=https://$VAANEE_DOMAIN/exotel/calls
NEXT_PUBLIC_PLATFORM_NAME=Vaanee
NEXT_PUBLIC_VAANEE_MODE=true

JWT_SECRET=$JWT_SECRET
ENCRYPTION_MASTER_KEY=$ENCRYPTION_MASTER_KEY
ENCRYPTION_SECRET=$ENCRYPTION_SECRET
INBOTIQ_API=$INBOTIQ_API
EOF

    cat > "$VAANEE_DIR/docker-compose.yml" << EOF
services:
  caddy:
    image: caddy:2-alpine
    container_name: vaanee-caddy
    restart: unless-stopped
    networks:
      - vaanee-network
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - vaanee-frontend
      - vaanee-backend
      - vaanee-webhook

  vaanee-backend:
    image: ${REGISTRY}/vaanee-backend:${ONPREM_IMAGE_TAG}
    container_name: vaanee-backend
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    environment:
      - N8N_CALLER_AI_WEBHOOK_URL=https://${VAANEE_DOMAIN}/exotel/calls
      - AI_WEBHOOK_BASE_URL=https://${VAANEE_DOMAIN}
      # The pronunciation proxy reaches the webhook over the INTERNAL docker network so
      # the webhook's /agents/* endpoints (which only check an X-Organization-Id header,
      # no token) don't have to be exposed publicly via Caddy (audit SEC).
      - VAANEE_WEBHOOK_INTERNAL_URL=http://vaanee-webhook:8000
      - CALLER_AI_CAMPAIGN_ENDPOINT_URL=https://${VAANEE_DOMAIN}/exotel/campaigns
      - N8N_CALLER_AI_FIRST_MESSAGE_WEBHOOK_URL=https://${VAANEE_DOMAIN}/exotel/answer
      # Read the per-org "Assigned" provider keys (Google for KB embeddings) that
      # the checkin container writes to the shared cache (audit P4/B1).
      - VAANEE_TELEPHONY_CACHE=/app/cache/telephony_cache.json
    volumes:
      - vaanee_cache:/app/cache
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/health >/dev/null 2>&1 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 45s

  vaanee-webhook:
    image: ${REGISTRY}/vaanee-webhook:${ONPREM_IMAGE_TAG}
    container_name: vaanee-webhook
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    environment:
      # Bind 8000 explicitly. The shared .env sets PORT=8080 (for backend/frontend),
      # but Caddy proxies @webhook -> vaanee-webhook:8000 and startup.sh honours
      # $PORT, so without this override the webhook would listen on 8080 and every
      # /exotel/* and /plivo/* request would 502 (audit BUILD-03).
      - PORT=8000
      - CALL_WEBSOCKET_URL=wss://${VAANEE_DOMAIN}/exotel/ws
      - WEBSOCKET_URL_HOST=${VAANEE_DOMAIN}
      - WEBSOCKET_URL_SCHEME=wss
      - WEBSOCKET_URL_PATH=/exotel/ws
      # Shared cache: the checkin container WRITES the licence/telephony cache
      # here and the webhook READS it for enforcement (audit C4/SCH-02 — without
      # a shared volume the read always missed and concurrency enforcement was
      # silently skipped because reads fail open).
      - VAANEE_LICENCE_CACHE=/app/cache/licence_cache.json
      - VAANEE_TELEPHONY_CACHE=/app/cache/telephony_cache.json
      # Persist the APScheduler SQLite jobstore on the shared volume so scheduled
      # calls / retries survive container restarts (audit SCH-05); the default
      # path lives under ephemeral /app and was lost on every restart.
      - RETRY_SCHEDULER_DB=/app/cache/retry_scheduler.db
    volumes:
      - vaanee_cache:/app/cache
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:8000/ >/dev/null 2>&1 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 45s

  vaanee-checkin:
    image: ${REGISTRY}/vaanee-webhook:${ONPREM_IMAGE_TAG}
    container_name: vaanee-checkin
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    environment:
      - VAANEE_LICENCE_CACHE=/app/cache/licence_cache.json
      - VAANEE_TELEPHONY_CACHE=/app/cache/telephony_cache.json
    volumes:
      - vaanee_cache:/app/cache
    command: ["python", "checkin_service.py"]
    healthcheck:
      disable: true

  vaanee-frontend:
    image: ${REGISTRY}/vaanee-frontend:${ONPREM_IMAGE_TAG}
    container_name: vaanee-frontend
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    depends_on:
      - vaanee-backend
      - vaanee-webhook
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/ >/dev/null 2>&1 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s

networks:
  vaanee-network:
    driver: bridge

volumes:
  caddy_data:
  caddy_config:
  vaanee_cache:
EOF

    # Local testing: use Caddy's self-signed cert instead of Let's Encrypt,
    # which cannot validate a non-public domain (e.g. on a VirtualBox VM).
    # Enable with: VAANEE_LOCAL_TLS=1 bash install.sh
    local tls_directive=""
    if [ "${VAANEE_LOCAL_TLS:-}" = "1" ]; then
        tls_directive=$'\n    tls internal'
    fi

    cat > "$VAANEE_DIR/Caddyfile" << EOF
{
    email ${ADMIN_EMAIL}
}

${VAANEE_DOMAIN} {${tls_directive}
    encode gzip

    # Backend (Express) serves ONLY /api/* and the root /health probe. UI routes
    # like /dashboard/*, /auth/*, /vaanee/* are Next.js frontend pages — routing
    # those bare paths here makes the backend 404 them (e.g. /dashboard/caller-ai-chatbot).
    @backend path /api/* /health
    handle @backend {
        reverse_proxy vaanee-backend:8080
    }

    # /agents/* is intentionally NOT proxied publicly: the webhook's
    # /agents/{id}/pronunciation-dictionary endpoints only check an X-Organization-Id
    # header (no token), so anyone who knew an org+agent UUID could tamper with
    # pronunciations via the org's Cartesia key. The backend reaches them over the
    # internal docker network instead (VAANEE_WEBHOOK_INTERNAL_URL above) (audit SEC).
    @webhook path /exotel/* /ws/* /plivo/*
    handle @webhook {
        reverse_proxy vaanee-webhook:8000
    }

    handle {
        reverse_proxy vaanee-frontend:8080
    }
}
EOF

    cp "$SCRIPT_DIR/../migrate.sql" "$VAANEE_DIR/migrate.sql"
    cp "$SCRIPT_DIR/../migrations/"*.sql "$VAANEE_DIR/migrations/"

    # HARDEN-D: seamless auto-updater — copy the script and install a systemd
    # timer so the VM converges on whatever image tag central advertises
    # (image_tag in the check-in), with health-check + rollback. Non-fatal.
    if cp "$SCRIPT_DIR/vaanee-update.sh" "$VAANEE_DIR/vaanee-update.sh" 2>/dev/null; then
        chmod +x "$VAANEE_DIR/vaanee-update.sh"
        if command -v systemctl >/dev/null 2>&1; then
            sudo tee /etc/systemd/system/vaanee-update.service >/dev/null << EOF
[Unit]
Description=Vaanee on-prem seamless auto-updater
After=docker.service
[Service]
Type=oneshot
ExecStart=/usr/bin/env bash $VAANEE_DIR/vaanee-update.sh
EOF
            sudo tee /etc/systemd/system/vaanee-update.timer >/dev/null << 'EOF'
[Unit]
Description=Run the Vaanee auto-updater periodically
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
Persistent=true
[Install]
WantedBy=timers.target
EOF
            sudo systemctl daemon-reload 2>/dev/null || true
            sudo systemctl enable --now vaanee-update.timer >/dev/null 2>&1 || true
            print_success "Auto-updater installed (systemd timer, every 15 min)"
        fi
    fi

    print_success "Files created at $VAANEE_DIR"
}

run_migrations() {
    print_step "Running database migrations"

    if ! command -v psql >/dev/null 2>&1; then
        print_warn "psql not found; installing postgresql-client..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq postgresql-client
    fi

    # Preflight: pgvector must be available BEFORE running migrations under
    # ON_ERROR_STOP, otherwise CREATE EXTENSION "vector" (001_extensions.sql)
    # aborts the ENTIRE run mid-flight on managed Postgres that doesn't
    # allow-list it, leaving a partial schema (audit D5/SCH-06).
    if ! psql "$DATABASE_URL" -tAc "SELECT 1 FROM pg_available_extensions WHERE name='vector'" 2>/dev/null | grep -q 1; then
        print_error "PostgreSQL extension 'vector' (pgvector) is not available on this server."
        echo "  Vaanee's knowledge base requires pgvector. Enable it, then re-run the installer:"
        echo "    - Azure Database for PostgreSQL: add VECTOR to server parameter 'azure.extensions', then restart the server."
        echo "    - Self-managed Postgres: install the matching 'postgresql-<version>-pgvector' package."
        echo "  Verify with:  psql \"\$DATABASE_URL\" -c \"SELECT name FROM pg_available_extensions WHERE name='vector';\""
        exit 1
    fi
    print_success "pgvector extension is available"

    (
        cd "$VAANEE_DIR"
        psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrate.sql
    )

    print_success "Database migrations completed"
}
