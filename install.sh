#!/bin/bash
set -e

# ============================================================
# Vaanee On-Premise Installer
# Usage: curl -fsSL https://get.vaanee.io/install.sh | bash
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_BASE_URL="${RAW_BASE_URL:-https://raw.githubusercontent.com/Inbotiq-com/vaanee-install/main}"

bootstrap_support_files() {
    if [ -f "$SCRIPT_DIR/lib/config.sh" ] && \
       [ -f "$SCRIPT_DIR/lib/ui.sh" ] && \
       [ -f "$SCRIPT_DIR/lib/steps.sh" ] && \
       [ -f "$SCRIPT_DIR/lib/steps/system.sh" ] && \
       [ -f "$SCRIPT_DIR/lib/steps/input_and_validation.sh" ] && \
       [ -f "$SCRIPT_DIR/lib/steps/files_and_migrations.sh" ] && \
       [ -f "$SCRIPT_DIR/lib/steps/runtime.sh" ]; then
        return 0
    fi

    mkdir -p "$SCRIPT_DIR/lib" "$SCRIPT_DIR/lib/steps"
    curl -fsSL "$RAW_BASE_URL/lib/config.sh" -o "$SCRIPT_DIR/lib/config.sh"
    curl -fsSL "$RAW_BASE_URL/lib/ui.sh" -o "$SCRIPT_DIR/lib/ui.sh"
    curl -fsSL "$RAW_BASE_URL/lib/steps.sh" -o "$SCRIPT_DIR/lib/steps.sh"
    curl -fsSL "$RAW_BASE_URL/lib/steps/system.sh" -o "$SCRIPT_DIR/lib/steps/system.sh"
    curl -fsSL "$RAW_BASE_URL/lib/steps/input_and_validation.sh" -o "$SCRIPT_DIR/lib/steps/input_and_validation.sh"
    curl -fsSL "$RAW_BASE_URL/lib/steps/files_and_migrations.sh" -o "$SCRIPT_DIR/lib/steps/files_and_migrations.sh"
    curl -fsSL "$RAW_BASE_URL/lib/steps/runtime.sh" -o "$SCRIPT_DIR/lib/steps/runtime.sh"
}

bootstrap_support_files

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=lib/steps.sh
source "$SCRIPT_DIR/lib/steps.sh"

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
    pull_images
    start_services
    install_cli
    wait_and_verify
}

main
