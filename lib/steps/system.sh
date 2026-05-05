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
