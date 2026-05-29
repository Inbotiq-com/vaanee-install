pull_images() {
    print_step "Pulling Vaanee images"
    echo "  This may take a few minutes depending on your connection..."
    echo ""

    # Login to registry with read-only pull token
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
    # cert is self-signed, so probe localhost and accept the self-signed cert.
    if [ "${VAANEE_LOCAL_TLS:-}" = "1" ]; then
        HEALTH_URL="https://localhost/health"
        HEALTH_CURL_OPTS="-sk"
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
