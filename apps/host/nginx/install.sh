#!/bin/bash

# Import Library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve utils.sh location (it is now in ../../../lib/utils.sh relative to apps/host/nginx/install.sh)
if [ -f "$SCRIPT_DIR/../../../lib/utils.sh" ]; then
    source "$SCRIPT_DIR/../../../lib/utils.sh"
elif [ -f "/tmp/lib/utils.sh" ]; then
    source "/tmp/lib/utils.sh"
else
    echo "Error: utils.sh not found."
    exit 1
fi

log_info ">>> STARTING NGINX INSTALLATION & SECURITY SETUP <<<"
detect_os

# --- INSTALLATION ---
if [ "$PACKAGE_MANAGER" == "apt" ]; then
    run_sudo apt-get update
    run_sudo apt-get install -y nginx
elif [ "$PACKAGE_MANAGER" == "yum" ]; then
    run_sudo yum install -y epel-release
    run_sudo yum install -y nginx
fi

# --- SECURITY HARDENING ---

log_info "Hardening Nginx Configuration..."

# Copy Standard Configurations from local folder (now they are next to the script)
CONFIG_SRC="$SCRIPT_DIR"

if [ -f "$CONFIG_SRC/security.conf" ]; then
    log_info "Applying standard configurations from $CONFIG_SRC..."
    
    # Create snippets directory if it doesn't exist
    run_sudo mkdir -p /etc/nginx/snippets

    # Copy configs to snippets instead of conf.d to avoid global conflicts
    run_sudo cp "$CONFIG_SRC/security.conf" /etc/nginx/snippets/security.conf
    run_sudo cp "$CONFIG_SRC/general.conf" /etc/nginx/snippets/general.conf
else
    log_error "Standard Nginx configurations not found in $CONFIG_SRC!"
fi

# 3. Firewall Configuration (UFW)
open_port 80 "Nginx HTTP"
open_port 443 "Nginx HTTPS"

# 4. Restart Service
run_sudo systemctl enable nginx
run_sudo systemctl restart nginx
run_sudo systemctl restart nginx

log_info "Nginx installed. Version hidden. Ports 80/443 Open."