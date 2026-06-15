#!/bin/bash
set -e

# ============================================================
# Vaanee On-Premise Installer
# Usage: curl -fsSL https://get.vaanee.io/install.sh | bash
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_BASE_URL="${RAW_BASE_URL:-https://raw.githubusercontent.com/Inbotiq-com/vaanee-install/main}"

bootstrap_support_files() {
    local migration_files=(
        "001_extensions.sql"
        "002_agents_and_flows.sql"
        "003_knowledge_base.sql"
        "004_calls_runtime.sql"
        "005_pronunciation_and_campaigns.sql"
        "006_indexes_and_finalize.sql"
        "007_telephony_and_config.sql"
        "008_knowledge_base_vectors.sql"
    )

    fetch_if_missing() {
        local relative_path="$1"
        local destination="$SCRIPT_DIR/$relative_path"

        if [ -f "$destination" ]; then
            return 0
        fi

        mkdir -p "$(dirname "$destination")"
        curl -fsSL "$RAW_BASE_URL/$relative_path" -o "$destination"
    }

    fetch_if_missing "lib/config.sh"
    fetch_if_missing "lib/ui.sh"
    fetch_if_missing "lib/steps.sh"
    fetch_if_missing "lib/steps/system.sh"
    fetch_if_missing "lib/steps/input_and_validation.sh"
    fetch_if_missing "lib/steps/files_and_migrations.sh"
    fetch_if_missing "lib/steps/runtime.sh"
    # HARDEN-D: the seamless auto-updater script. WITHOUT this fetch, a
    # `curl | bash` install never downloads it, the cp in files_and_migrations.sh
    # silently fails, and the VM ships with NO working auto-updater (the systemd
    # timer fires but exits 127 on a missing script). This was the root cause of
    # on-prem VMs never converging on a newly-published image tag.
    fetch_if_missing "lib/vaanee-update.sh"
    fetch_if_missing "migrate.sql"

    for migration_file in "${migration_files[@]}"; do
        fetch_if_missing "migrations/$migration_file"
    done
}

bootstrap_support_files

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=lib/steps.sh
source "$SCRIPT_DIR/lib/steps.sh"

main() {
    # Re-open stdin from the terminal when piped via `curl | bash` (interactive
    # installs). Guarded so automated/non-interactive installs (no controlling
    # tty, answers supplied via env vars) don't abort with
    # "/dev/tty: No such device or address" — audit INSTALL-TTY.
    if { : < /dev/tty; } 2>/dev/null; then
        exec < /dev/tty
    fi

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
