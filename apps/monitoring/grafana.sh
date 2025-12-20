#!/bin/bash

# Import Library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../../lib/utils.sh" ]; then
    source "$SCRIPT_DIR/../../lib/utils.sh"
elif [ -f "/tmp/lib/utils.sh" ]; then
    source "/tmp/lib/utils.sh"
else
    echo "Error: utils.sh not found."
    exit 1
fi

log_info ">>> STARTING GRAFANA INSTALLATION <<<"

if ! command -v docker >/dev/null; then
    log_error "Docker is not installed."
    exit 1
fi

# 1. Create Shared Network
log_info "Ensuring 'vps_network' Docker network exists..."
run_sudo docker network create vps_network 2>/dev/null || true

# 2. Prepare Directories
BASE_DIR="/opt/monitoring/grafana"
run_sudo mkdir -p "$BASE_DIR/data"
run_sudo chown -R 472:472 "$BASE_DIR/data" 2>/dev/null || true

# Manage Credentials
manage_credentials "grafana" "GF_SECURITY_ADMIN_PASSWORD"

# 3. Run Grafana Container
# CHANGE: Mapping external port 3100 to internal 3000 to avoid Next.js conflict
log_info "Deploying Grafana Container..."
run_sudo docker run -d \
    --name grafana \
    --network vps_network \
    --restart unless-stopped \
    -p 3100:3000 \
    -e GF_SECURITY_ADMIN_PASSWORD="$GF_SECURITY_ADMIN_PASSWORD" \
    -v "$BASE_DIR/data":/var/lib/grafana \
    grafana/grafana:latest

# 4. Firewall
# CHANGE: Opening 3100 instead of 3000
open_port 3100 "Grafana Dashboard (Alternative Port)"

log_info "Grafana installed."
log_info "   - URL: http://YOUR_IP:3100"
log_info "   - Note: Port 3100 used to leave 3000 free for Node.js/Next.js apps."
log_info "   - Default User: admin / admin"