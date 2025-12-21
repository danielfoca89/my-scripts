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

log_info ">>> STARTING UPTIME KUMA INSTALLATION <<<"

require_docker

log_info "Creating Volume..."
run_sudo docker volume create uptime-kuma

log_info "Deploying Uptime Kuma Container..."
run_sudo docker run -d --restart=always --network vps_network -p 3001:3001 -v uptime-kuma:/app/data --name uptime-kuma louislam/uptime-kuma:1

# --- FIREWALL ---
log_info "Opening Port 3001 for Uptime Kuma..."
open_port 3001 "Uptime Kuma Dashboard"

log_info "Uptime Kuma running at http://YOUR_IP:3001"