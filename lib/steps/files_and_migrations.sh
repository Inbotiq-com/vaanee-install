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
    image: ${REGISTRY}/vaanee-backend:2026-05-08-fix-login
    container_name: vaanee-backend
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    environment:
      - N8N_CALLER_AI_WEBHOOK_URL=https://${VAANEE_DOMAIN}/exotel/calls
      - AI_WEBHOOK_BASE_URL=https://${VAANEE_DOMAIN}
      - CALLER_AI_CAMPAIGN_ENDPOINT_URL=https://${VAANEE_DOMAIN}/exotel/campaigns
      - N8N_CALLER_AI_FIRST_MESSAGE_WEBHOOK_URL=https://${VAANEE_DOMAIN}/exotel/answer
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/health >/dev/null 2>&1 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 45s

  vaanee-webhook:
    image: ${REGISTRY}/vaanee-webhook:qa
    container_name: vaanee-webhook
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    environment:
      - CALL_WEBSOCKET_URL=wss://${VAANEE_DOMAIN}/exotel/ws
      - WEBSOCKET_URL_HOST=${VAANEE_DOMAIN}
      - WEBSOCKET_URL_SCHEME=wss
      - WEBSOCKET_URL_PATH=/exotel/ws

  vaanee-checkin:
    image: ${REGISTRY}/vaanee-webhook:qa
    container_name: vaanee-checkin
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    command: ["python", "checkin_service.py"]
    healthcheck:
      disable: true

  vaanee-frontend:
    image: ${REGISTRY}/vaanee-frontend:qa
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

    @webhook path /exotel/* /ws/* /agents/*
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

    print_success "Files created at $VAANEE_DIR"
}

run_migrations() {
    print_step "Running database migrations"

    if ! command -v psql >/dev/null 2>&1; then
        print_warn "psql not found; installing postgresql-client..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq postgresql-client
    fi

    (
        cd "$VAANEE_DIR"
        psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrate.sql
    )

    print_success "Database migrations completed"
}
