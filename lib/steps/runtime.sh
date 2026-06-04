# Fetch the read-only registry pull token from the central Inbotiq server using the
# licence key (audit INSTALL-REG-01), so the dashboard guide only needs API key / domain
# / DB / email — no registry secret in the client's hands or in installer source.
fetch_registry_credentials() {
    local base resp r u p
    base="${INBOTIQ_API:-}"
    [ -z "$base" ] && return 1
    [ -z "${VAANEE_API_KEY:-}" ] && return 1
    resp=$(curl -fsS --max-time 25 -H "Authorization: Bearer $VAANEE_API_KEY" \
        "${base%/}/vaanee/registry-credentials" 2>/dev/null) || return 1
    p=$(echo "$resp" | grep -oE '"password":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//')
    [ -n "$p" ] || return 1
    r=$(echo "$resp" | grep -oE '"registry":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//')
    u=$(echo "$resp" | grep -oE '"username":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//')
    [ -n "$r" ] && REGISTRY="$r"
    [ -n "$u" ] && REGISTRY_USER="$u"
    REGISTRY_PASS="$p"
    print_success "Registry credentials fetched from Inbotiq"
    return 0
}

pull_images() {
    print_step "Pulling Vaanee images"
    echo "  This may take a few minutes depending on your connection..."
    echo ""

    # Obtain the read-only registry pull token. Preferred: fetch it from the central
    # server with the licence key (the guide only asks for API key/domain/DB/email).
    # Fall back to a REGISTRY_PASS provided in the environment (explicit per-customer token).
    if [ -z "${REGISTRY_PASS:-}" ]; then
        fetch_registry_credentials || true
    fi
    if [ -z "${REGISTRY_PASS:-}" ]; then
        print_error "Could not obtain registry credentials from the Inbotiq server and no"
        echo "    REGISTRY_PASS was provided. Check VAANEE_API_KEY / network, or pass"
        echo "    REGISTRY_PASS='<token>' bash install.sh"
        exit 1
    fi
    echo "$REGISTRY_PASS" | sudo docker login "$REGISTRY" \
        --username "$REGISTRY_USER" \
        --password-stdin

    (
        cd "$VAANEE_DIR"
        sudo docker compose pull
    )
    print_success "Images pulled"
}

# ============================================================
# 9. Start services
# ============================================================
start_services() {
    print_step "Starting Vaanee"
    (
        cd "$VAANEE_DIR"
        sudo docker compose up -d
    )
    print_success "Containers started"
}

# ============================================================
# 10. Wait for healthy and print result
# ============================================================
wait_and_verify() {
    print_step "Waiting for Vaanee to be ready"
    echo ""

    # Local testing: the public domain won't resolve from this host and the
    # cert is self-signed. Caddy only serves the configured site name, so we
    # must present that hostname (SNI) while connecting to 127.0.0.1, and
    # accept the self-signed cert.
    if [ "${VAANEE_LOCAL_TLS:-}" = "1" ]; then
        HEALTH_URL="https://$VAANEE_DOMAIN/health"
        HEALTH_CURL_OPTS="-sk --resolve $VAANEE_DOMAIN:443:127.0.0.1"
    else
        HEALTH_URL="https://$VAANEE_DOMAIN/health"
        HEALTH_CURL_OPTS="-s"
    fi

    MAX_WAIT=120
    ELAPSED=0
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        HTTP=$(curl $HEALTH_CURL_OPTS -o /dev/null -w "%{http_code}" "$HEALTH_URL" --max-time 5 2>/dev/null || echo "000")
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
        if [ "${VAANEE_LOCAL_TLS:-}" = "1" ]; then
            echo -e "  ${BOLD}Note:${NC}    Local TLS mode (self-signed). On the machine with the browser,"
            echo -e "           map the domain to this VM's IP in your hosts file, e.g.:"
            echo -e "             $(hostname -I | awk '{print $1}')   $VAANEE_DOMAIN"
            echo -e "           Then accept the browser's self-signed cert warning."
        fi
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
        # Reclaim disk from the now-unused old image layers (audit OPS-01): repeated
        # updates otherwise accumulate dangling images and fill small VM disks, which
        # makes a later `docker compose up` fail with "no space left on device".
        echo "Reclaiming disk from old images..."
        docker image prune -f >/dev/null 2>&1 || true
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
