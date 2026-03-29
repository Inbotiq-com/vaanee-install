#!/bin/bash
set -e

# ============================================================
# Vaanee On-Premise Installer
# Usage: curl -fsSL https://get.vaanee.io/install.sh | bash
# ============================================================

VAANEE_DIR="$HOME/vaanee"
REGISTRY="inbotiqregistry.azurecr.io"
REGISTRY_USER="vaanee-client-pull"
REGISTRY_PASS="2oAJxC3KyNpFCYMytYlQo1Qul6VrpwksX6kqcCvhpAcwX7U0LtwDJQQJ99CCACGhslBEqg7NAAABAZCRKxM0"
INBOTIQ_API="https://inbotiq-backend-qa.azurewebsites.net/api"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_logo() {
    echo ""
    echo -e "${BLUE}${BOLD}"
    echo "  ██╗   ██╗ █████╗  █████╗ ███╗   ██╗███████╗███████╗"
    echo "  ██║   ██║██╔══██╗██╔══██╗████╗  ██║██╔════╝██╔════╝"
    echo "  ██║   ██║███████║███████║██╔██╗ ██║█████╗  █████╗  "
    echo "  ╚██╗ ██╔╝██╔══██║██╔══██║██║╚██╗██║██╔══╝  ██╔══╝  "
    echo "   ╚████╔╝ ██║  ██║██║  ██║██║ ╚████║███████╗███████╗"
    echo "    ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
    echo -e "${NC}"
    echo -e "${BOLD}  On-Premise Installer${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}${BOLD}==>${NC}${BOLD} $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# ============================================================
# 1. Check OS
# ============================================================
check_os() {
    print_step "Checking system requirements"

    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "Vaanee requires Linux (Ubuntu 20.04+). Detected: $OSTYPE"
        exit 1
    fi

    . /etc/os-release 2>/dev/null || true
    OS_NAME="${NAME:-Linux}"
    OS_VERSION="${VERSION_ID:-unknown}"
    print_success "OS: $OS_NAME $OS_VERSION"

    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
        print_error "Unsupported architecture: $ARCH. Vaanee supports x86_64 and arm64."
        exit 1
    fi
    print_success "Architecture: $ARCH"

    MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_GB=$(echo "scale=1; $MEM_KB/1024/1024" | bc)
    if [ "$MEM_KB" -lt 3500000 ]; then
        print_warn "RAM: ${MEM_GB}GB detected. Minimum 4GB recommended."
    else
        print_success "RAM: ${MEM_GB}GB"
    fi

    CPU=$(nproc)
    if [ "$CPU" -lt 2 ]; then
        print_warn "CPU: ${CPU} core detected. Minimum 2 cores recommended."
    else
        print_success "CPUs: $CPU"
    fi
}

# ============================================================
# 2. Install Docker if not present
# ============================================================
install_docker() {
    print_step "Checking Docker"

    if command -v docker &>/dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
        print_success "Docker already installed: $DOCKER_VERSION"
    else
        print_warn "Docker not found. Installing Docker..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo usermod -aG docker "$USER" || true
        print_success "Docker installed"
    fi

    if ! command -v docker &>/dev/null; then
        print_error "Docker installation failed. Please install Docker manually: https://docs.docker.com/engine/install/"
        exit 1
    fi

    # Install Docker Compose plugin if needed
    if ! docker compose version &>/dev/null 2>&1; then
        print_warn "Docker Compose plugin not found. Installing..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-compose-plugin
        print_success "Docker Compose plugin installed"
    else
        print_success "Docker Compose: $(docker compose version --short)"
    fi
}

# ============================================================
# 3. Check ports
# ============================================================
check_ports() {
    print_step "Checking required ports (80, 443)"

    for PORT in 80 443; do
        if ss -tlnp 2>/dev/null | grep -q ":$PORT " || netstat -tlnp 2>/dev/null | grep -q ":$PORT "; then
            print_error "Port $PORT is already in use. Please free it before running the installer."
            echo "  Run: sudo lsof -i :$PORT"
            exit 1
        else
            print_success "Port $PORT is available"
        fi
    done
}

# ============================================================
# 4. Collect user inputs
# ============================================================
collect_inputs() {
    print_step "Configuration"
    echo ""

    # API Key
    echo -e "${BOLD}Your Vaanee API Key${NC}"
    echo "  Find this in your Vaanee dashboard under Settings → On-Premise Package"
    echo ""
    while true; do
        read -rp "  Enter your VAANEE_API_KEY: " VAANEE_API_KEY
        if [[ "$VAANEE_API_KEY" == vaan_live_* ]]; then
            break
        else
            print_error "Invalid API key format. It should start with 'vaan_live_'"
        fi
    done
    echo ""

    # Domain
    echo -e "${BOLD}Your Domain${NC}"
    echo "  Vaanee will be available at https://yourdomain.com"
    echo "  Make sure your domain's DNS A record already points to this server's IP."
    echo ""
    while true; do
        read -rp "  Enter your domain (e.g. vaanee.yourcompany.com): " VAANEE_DOMAIN
        VAANEE_DOMAIN=$(echo "$VAANEE_DOMAIN" | tr '[:upper:]' '[:lower:]' | sed 's|https\?://||g' | sed 's|/.*||g')
        if [[ "$VAANEE_DOMAIN" =~ ^[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?)+$ ]]; then
            break
        else
            print_error "Invalid domain format. Enter a valid domain like vaanee.yourcompany.com"
        fi
    done
    echo ""

    # Database URL
    echo -e "${BOLD}Your PostgreSQL Database URL${NC}"
    echo "  Format: postgresql://user:password@host:5432/dbname"
    echo "  The database must already exist. Vaanee will run migrations automatically."
    echo ""
    while true; do
        read -rp "  Enter your DATABASE_URL: " DATABASE_URL
        if [[ "$DATABASE_URL" == postgresql://* || "$DATABASE_URL" == postgres://* ]]; then
            break
        else
            print_error "Invalid database URL. Must start with postgresql:// or postgres://"
        fi
    done
    echo ""

    # Email for SSL cert
    echo -e "${BOLD}Your Email Address${NC}"
    echo "  Used for SSL certificate registration (Let's Encrypt). You'll receive expiry notices here."
    echo ""
    while true; do
        read -rp "  Enter your email: " ADMIN_EMAIL
        if [[ "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "Invalid email format."
        fi
    done
    echo ""

    # Confirm
    echo -e "${BOLD}Summary${NC}"
    echo "  Domain:   https://$VAANEE_DOMAIN"
    echo "  Email:    $ADMIN_EMAIL"
    echo "  API Key:  ${VAANEE_API_KEY:0:20}..."
    echo "  Database: ${DATABASE_URL:0:30}..."
    echo ""
    read -rp "  Proceed with installation? [Y/n]: " CONFIRM
    CONFIRM=${CONFIRM:-Y}
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
}

# ============================================================
# 5. Validate API key against Inbotiq platform
# ============================================================
validate_api_key() {
    print_step "Validating API key"

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $VAANEE_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"instance_id":"installer","version":"1.0.0"}' \
        -X POST "$INBOTIQ_API/vaanee/check-in" \
        --max-time 10 2>/dev/null || echo "000")

    if [ "$HTTP_STATUS" = "000" ]; then
        print_warn "Could not reach Inbotiq platform to validate key. Continuing anyway..."
    elif [ "$HTTP_STATUS" = "401" ]; then
        print_error "Invalid API key. Please check your key in the Vaanee dashboard."
        exit 1
    elif [ "$HTTP_STATUS" = "410" ]; then
        print_error "Your licence has been cancelled. Contact support@inbotiq.com"
        exit 1
    elif [ "$HTTP_STATUS" = "402" ]; then
        print_error "Your subscription has expired. Contact support@inbotiq.com"
        exit 1
    else
        print_success "API key validated"
    fi
}

# ============================================================
# 6. Generate secrets
# ============================================================
generate_secrets() {
    JWT_SECRET=$(openssl rand -hex 32)
    ENCRYPTION_MASTER_KEY=$(openssl rand -hex 32)
}

# ============================================================
# 7. Write files
# ============================================================
write_files() {
    print_step "Creating Vaanee directory at $VAANEE_DIR"
    mkdir -p "$VAANEE_DIR"
    cd "$VAANEE_DIR"

    # ── .env ──────────────────────────────────────────────
    cat > .env << EOF
# Vaanee On-Premise Configuration
# Generated by installer on $(date)

# ── Licence ──────────────────────────────────────────────
VAANEE_API_KEY=$VAANEE_API_KEY
INSTANCE_ID=$(hostname)-$(openssl rand -hex 4)

# ── Database ─────────────────────────────────────────────
DATABASE_URL=${DATABASE_URL}&keepalives=1&keepalives_idle=30&keepalives_interval=10&keepalives_count=5&connect_timeout=10

# ── App ──────────────────────────────────────────────────
NODE_ENV=production
PORT=8080
VAANEE_MODE=true

# ── Security ─────────────────────────────────────────────
JWT_SECRET=$JWT_SECRET
ENCRYPTION_MASTER_KEY=$ENCRYPTION_MASTER_KEY

# ── Frontend ─────────────────────────────────────────────
NEXT_PUBLIC_API_URL=https://$VAANEE_DOMAIN
NEXT_PUBLIC_BACKEND_URL=https://$VAANEE_DOMAIN
NEXT_PUBLIC_CALLER_AI_BASE_URL=https://$VAANEE_DOMAIN
NEXT_PUBLIC_SEO_BACKEND_URL=https://$VAANEE_DOMAIN
NEXT_PUBLIC_PLATFORM_NAME=Vaanee
NEXT_PUBLIC_MAIN_APP_URL=https://$VAANEE_DOMAIN

# ── Domain ───────────────────────────────────────────────
VAANEE_DOMAIN=$VAANEE_DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
EOF

    print_success ".env created"

    # ── Caddyfile ─────────────────────────────────────────
    cat > Caddyfile << EOF
$VAANEE_DOMAIN {
    tls $ADMIN_EMAIL

    handle /api/login {
        reverse_proxy vaanee-frontend:8080
    }

    handle /api/auth/* {
        reverse_proxy vaanee-frontend:8080
    }

    handle /api/* {
        reverse_proxy vaanee-backend:8080
    }

    handle /exotel/* {
        reverse_proxy vaanee-webhook:8000 {
            header_up Host {host}
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-Host {host}
        }
    }

    handle /flow/* {
        reverse_proxy vaanee-webhook:8000 {
            header_up Host {host}
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-Host {host}
        }
    }

    handle /answer {
        reverse_proxy vaanee-webhook:8000 {
            header_up Host {host}
            header_up X-Forwarded-Proto {scheme}
        }
    }

    handle /calls {
        reverse_proxy vaanee-webhook:8000 {
            header_up Host {host}
            header_up X-Forwarded-Proto {scheme}
        }
    }

    handle /webhook/* {
        reverse_proxy vaanee-webhook:8000
    }

    handle /health {
        reverse_proxy vaanee-backend:8080
    }

    handle {
        reverse_proxy vaanee-frontend:8080
    }
}
EOF

    print_success "Caddyfile created"

    # ── docker-compose.yml ────────────────────────────────
    cat > docker-compose.yml << EOF
networks:
  vaanee-network:
    driver: bridge

volumes:
  caddy_data:
  caddy_config:

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
    image: $REGISTRY/vaanee-backend:qa
    container_name: vaanee-backend
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    environment:
      - N8N_CALLER_AI_WEBHOOK_URL=https://$VAANEE_DOMAIN/exotel/calls
      - AI_WEBHOOK_BASE_URL=https://$VAANEE_DOMAIN
      - CALLER_AI_CAMPAIGN_ENDPOINT_URL=https://$VAANEE_DOMAIN/exotel/campaigns
      - N8N_CALLER_AI_FIRST_MESSAGE_WEBHOOK_URL=https://$VAANEE_DOMAIN/exotel/answer

  vaanee-webhook:
    image: $REGISTRY/vaanee-webhook:qa
    container_name: vaanee-webhook
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    environment:
      - CALL_WEBSOCKET_URL=wss://$VAANEE_DOMAIN/exotel/ws
      - WEBSOCKET_URL_HOST=$VAANEE_DOMAIN
      - WEBSOCKET_URL_SCHEME=wss
      - WEBSOCKET_URL_PATH=/exotel/ws

  vaanee-checkin:
    image: $REGISTRY/vaanee-webhook:qa
    container_name: vaanee-checkin
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    command: ["python", "checkin_service.py"]

  vaanee-frontend:
    image: $REGISTRY/vaanee-frontend:qa
    container_name: vaanee-frontend
    restart: unless-stopped
    networks:
      - vaanee-network
    env_file:
      - .env
    depends_on:
      - vaanee-backend
      - vaanee-webhook
EOF

    print_success "docker-compose.yml created"

    # Download migration SQL
    curl -fsSL https://raw.githubusercontent.com/Inbotiq-com/vaanee-install/main/migrate.sql -o migrate.sql
    print_success "Migration script downloaded"
}

# ============================================================
# 7b. Run database migrations
# ============================================================
run_migrations() {
    print_step "Running database migrations"

    if ! command -v psql &>/dev/null; then
        print_warn "Installing PostgreSQL client..."
        sudo apt-get install -y -qq postgresql-client 2>/dev/null || \
        sudo apt-get install -y -qq postgresql-client-14 2>/dev/null || \
        sudo apt-get install -y -qq postgresql-client-16 2>/dev/null || true
    fi

    if command -v psql &>/dev/null; then
        psql "$DATABASE_URL" -f "$VAANEE_DIR/migrate.sql" -v ON_ERROR_STOP=0 2>&1 | grep -E "NOTICE|ERROR|error" || true
        print_success "Database migrations completed"
    else
        print_warn "psql not available — skipping auto migration."
        echo ""
        echo "  Run migrations manually before starting Vaanee:"
        echo "    psql \"$DATABASE_URL\" -f $VAANEE_DIR/migrate.sql"
        echo ""
    fi
}

# ============================================================
# 7c. Bootstrap — seed org and user from Inbotiq platform
# ============================================================
bootstrap_db() {
    print_step "Fetching your account data from Inbotiq"

    BOOTSTRAP=$(curl -s -H "Authorization: Bearer $VAANEE_API_KEY" \
        "$INBOTIQ_API/vaanee/bootstrap" --max-time 15 2>/dev/null) || true

    HTTP_CHECK=$(echo "$BOOTSTRAP" | grep -c '"organization"' 2>/dev/null || echo "0")
    if [ -z "$BOOTSTRAP" ] || [ "$HTTP_CHECK" -eq 0 ]; then
        print_warn "Could not fetch account data. Skipping bootstrap."
        print_warn "Login with same credentials you use on app.inbotiq.ai"
        return
    fi

    ORG_ID=$(echo "$BOOTSTRAP" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    ORG_NAME=$(echo "$BOOTSTRAP" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
    USER_ID=$(echo "$BOOTSTRAP" | grep -o '"id":"[^"]*"' | sed -n '2p' | cut -d'"' -f4)
    USER_EMAIL=$(echo "$BOOTSTRAP" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
    USER_HASH=$(echo "$BOOTSTRAP" | grep -o '"password_hash":"[^"]*"' | cut -d'"' -f4)
    USER_FIRST=$(echo "$BOOTSTRAP" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
    USER_LAST=$(echo "$BOOTSTRAP" | grep -o '"last_name":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$ORG_ID" ] || [ -z "$USER_EMAIL" ]; then
        print_warn "Could not parse account data. Skipping bootstrap."
        return
    fi

    if command -v psql &>/dev/null; then
        psql "$DATABASE_URL" -v ON_ERROR_STOP=0 2>/dev/null << SQLEOF
INSERT INTO organizations (id, name, is_active)
VALUES ('$ORG_ID', '$ORG_NAME', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO users (id, organization_id, email, password_hash, first_name, last_name, is_active)
VALUES ('$USER_ID', '$ORG_ID', '$USER_EMAIL', '$USER_HASH', '$USER_FIRST', '$USER_LAST', true)
ON CONFLICT (id) DO NOTHING;
SQLEOF

        # Seed telephony config if present in bootstrap response
        TELE_SID=$(echo "$BOOTSTRAP" | grep -o '"exotel_account_sid":"[^"]*"' | cut -d'"' -f4)
        TELE_KEY=$(echo "$BOOTSTRAP" | grep -o '"exotel_api_key":"[^"]*"' | cut -d'"' -f4)
        TELE_TOKEN=$(echo "$BOOTSTRAP" | grep -o '"exotel_api_token":"[^"]*"' | cut -d'"' -f4)
        TELE_SUB=$(echo "$BOOTSTRAP" | grep -o '"exotel_subdomain":"[^"]*"' | cut -d'"' -f4)
        TELE_APP=$(echo "$BOOTSTRAP" | grep -o '"exotel_app_id":"[^"]*"' | cut -d'"' -f4)

        if [ -n "$TELE_SID" ] && [ -n "$TELE_KEY" ] && [ -n "$TELE_TOKEN" ]; then
            psql "$DATABASE_URL" -v ON_ERROR_STOP=0 2>/dev/null << SQLEOF
INSERT INTO organization_caller_ai_config
  (organization_id, exotel_account_sid, exotel_api_key, exotel_api_token,
   exotel_subdomain, exotel_app_id, campaign_flow_id, exotel_is_active, telephony_enabled, kyc_status)
VALUES
  ('$ORG_ID', '$TELE_SID', '$TELE_KEY', '$TELE_TOKEN',
   '${TELE_SUB:-api.exotel.com}', '${TELE_APP:-}', '${TELE_APP:-}', true, true, 'approved')
ON CONFLICT (organization_id) DO UPDATE SET
  exotel_account_sid = EXCLUDED.exotel_account_sid,
  exotel_api_key = EXCLUDED.exotel_api_key,
  exotel_api_token = EXCLUDED.exotel_api_token,
  exotel_subdomain = EXCLUDED.exotel_subdomain,
  exotel_app_id = EXCLUDED.exotel_app_id,
  campaign_flow_id = EXCLUDED.campaign_flow_id,
  telephony_enabled = true,
  kyc_status = 'approved',
  updated_at = NOW();
SQLEOF
            print_success "Telephony config seeded"
        fi

        print_success "Account seeded — login with: $USER_EMAIL"
    else
        print_warn "psql not available — skipping account seed."
    fi
}

# ============================================================
# 8. Login to registry and pull images
# ============================================================
pull_images() {
    print_step "Pulling Vaanee images"
    echo "  This may take a few minutes depending on your connection..."
    echo ""

    # Login to registry with read-only pull token
    echo "$REGISTRY_PASS" | sudo docker login "$REGISTRY" \
        --username "$REGISTRY_USER" \
        --password-stdin

    sudo docker compose pull
    print_success "Images pulled"
}

# ============================================================
# 9. Start services
# ============================================================
start_services() {
    print_step "Starting Vaanee"
    sudo docker compose up -d
    print_success "Containers started"
}

# ============================================================
# 10. Wait for healthy and print result
# ============================================================
wait_and_verify() {
    print_step "Waiting for Vaanee to be ready"
    echo ""

    MAX_WAIT=120
    ELAPSED=0
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        HTTP=$(curl -s -o /dev/null -w "%{http_code}" "https://$VAANEE_DOMAIN/health" --max-time 5 2>/dev/null || echo "000")
        if [ "$HTTP" = "200" ]; then
            break
        fi
        printf "  Waiting... (%ds)\r" "$ELAPSED"
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done

    echo ""

    if [ "$HTTP" = "200" ]; then
        echo ""
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}  Vaanee is ready!${NC}"
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BOLD}URL:${NC}     https://$VAANEE_DOMAIN"
        echo -e "  ${BOLD}Logs:${NC}    cd $VAANEE_DIR && docker compose logs -f"
        echo -e "  ${BOLD}Update:${NC}  cd $VAANEE_DIR && docker compose pull && docker compose up -d"
        echo -e "  ${BOLD}Stop:${NC}    cd $VAANEE_DIR && docker compose down"
        echo ""
        echo -e "  ${BOLD}Support:${NC} support@inbotiq.com"
        echo ""
    else
        echo ""
        print_warn "Vaanee started but health check timed out."
        echo ""
        echo "  This is usually because:"
        echo "  1. DNS hasn't propagated yet — wait a few minutes and visit https://$VAANEE_DOMAIN"
        echo "  2. Ports 80/443 are blocked by your firewall"
        echo ""
        echo "  Check logs with:"
        echo "    cd $VAANEE_DIR && docker compose logs"
        echo ""
        echo "  Contact support@inbotiq.com if the issue persists."
    fi
}

# ============================================================
# 11. Create vaanee CLI helper
# ============================================================
install_cli() {
    sudo tee /usr/local/bin/vaanee > /dev/null << 'CLI'
#!/bin/bash
VAANEE_DIR="$HOME/vaanee"
cd "$VAANEE_DIR" || { echo "Vaanee directory not found at $VAANEE_DIR"; exit 1; }

case "$1" in
    start)   docker compose up -d ;;
    stop)    docker compose down ;;
    restart) docker compose restart ;;
    update)
        echo "Pulling latest images..."
        docker compose pull
        docker compose up -d
        echo "Done."
        ;;
    logs)    docker compose logs -f "${2:-}" ;;
    status)  docker compose ps ;;
    *)
        echo "Vaanee CLI"
        echo ""
        echo "Usage: vaanee <command>"
        echo ""
        echo "Commands:"
        echo "  start     Start Vaanee"
        echo "  stop      Stop Vaanee"
        echo "  restart   Restart Vaanee"
        echo "  update    Pull latest images and restart"
        echo "  logs      View logs (optional: vaanee logs backend)"
        echo "  status    Show container status"
        ;;
esac
CLI

    sudo chmod +x /usr/local/bin/vaanee 2>/dev/null || true
    print_success "vaanee CLI installed — run 'vaanee' anytime to manage your installation"
}

# ============================================================
# Main
# ============================================================
main() {
    # Re-open stdin from terminal when piped via curl | bash
    exec < /dev/tty

    print_logo
    check_os
    install_docker
    check_ports
    collect_inputs
    validate_api_key
    generate_secrets
    write_files
    run_migrations
    bootstrap_db
    pull_images
    start_services
    install_cli
    wait_and_verify
}

main
