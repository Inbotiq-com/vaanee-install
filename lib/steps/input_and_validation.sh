collect_inputs() {
    print_step "Configuration"
    echo ""

    # Non-interactive support (audit INSTALL-TTY): each value may be supplied via
    # an environment variable (VAANEE_API_KEY / VAANEE_DOMAIN / DATABASE_URL /
    # ADMIN_EMAIL). When set and valid it is used as-is; otherwise the installer
    # prompts. Set NONINTERACTIVE=1 to skip the final confirmation (e.g. CI / cron).

    # API Key
    if [ -n "${VAANEE_API_KEY:-}" ] && [[ "$VAANEE_API_KEY" == vaan_live_* ]]; then
        print_success "Using VAANEE_API_KEY from environment"
    else
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
    fi

    # Domain
    VAANEE_DOMAIN=$(echo "${VAANEE_DOMAIN:-}" | tr '[:upper:]' '[:lower:]' | sed 's|https\?://||g' | sed 's|/.*||g')
    if [[ "$VAANEE_DOMAIN" =~ ^[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?)+$ ]]; then
        print_success "Using VAANEE_DOMAIN from environment: $VAANEE_DOMAIN"
    else
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
    fi

    # Database URL
    if [ -n "${DATABASE_URL:-}" ] && [[ "$DATABASE_URL" == postgresql://* || "$DATABASE_URL" == postgres://* ]]; then
        print_success "Using DATABASE_URL from environment"
    else
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
    fi

    # Email for SSL cert
    if [ -n "${ADMIN_EMAIL:-}" ] && [[ "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_success "Using ADMIN_EMAIL from environment"
    else
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
    fi

    # Confirm
    echo -e "${BOLD}Summary${NC}"
    echo "  Domain:   https://$VAANEE_DOMAIN"
    echo "  Email:    $ADMIN_EMAIL"
    echo "  API Key:  ${VAANEE_API_KEY:0:20}..."
    echo "  Database: ${DATABASE_URL:0:30}..."
    echo ""
    if [ "${NONINTERACTIVE:-}" = "1" ]; then
        echo "  NONINTERACTIVE=1 — proceeding without confirmation."
        CONFIRM=Y
    else
        read -rp "  Proceed with installation? [Y/n]: " CONFIRM
        CONFIRM=${CONFIRM:-Y}
    fi
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
    ENCRYPTION_SECRET=$(openssl rand -hex 32)
}

# ============================================================
# 7. Write files
# ============================================================
