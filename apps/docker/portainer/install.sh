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

log_info ">>> STARTING PORTAINER INSTALLATION <<<"

require_docker

log_info "Creating Portainer Volume..."
run_sudo docker volume create portainer_data

log_info "Deploying Portainer CE Container..."
# Runs Portainer with persistent storage and automatic restart
run_sudo docker run -d -p 8000:8000 -p 9443:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

# --- FIREWALL ---
log_info "Configuring Firewall for Portainer HTTPS..."
open_port 9443 "Portainer HTTPS Interface"

log_info "Portainer running at https://YOUR_IP:9443"