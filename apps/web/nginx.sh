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

# Copy Standard Configurations from lib/config/nginx
# We look for them relative to the script or in /tmp/lib
CONFIG_SRC=""
if [ -d "$SCRIPT_DIR/../../lib/config/nginx" ]; then
    CONFIG_SRC="$SCRIPT_DIR/../../lib/config/nginx"
elif [ -d "/tmp/lib/config/nginx" ]; then
    CONFIG_SRC="/tmp/lib/config/nginx"
fi

if [ -n "$CONFIG_SRC" ]; then
    log_info "Applying standard configurations from $CONFIG_SRC..."
    run_sudo cp "$CONFIG_SRC/security.conf" /etc/nginx/conf.d/99-security.conf
    run_sudo cp "$CONFIG_SRC/general.conf" /etc/nginx/conf.d/99-general.conf
else
    log_error "Standard Nginx configurations not found!"
fi

# 3. Firewall Configuration (UFW)
open_port 80 "Nginx HTTP"
open_port 443 "Nginx HTTPS"

# 4. Restart Service
run_sudo systemctl enable nginx
run_sudo systemctl restart nginx
run_sudo systemctl restart nginx

log_info "Nginx installed. Version hidden. Ports 80/443 Open."