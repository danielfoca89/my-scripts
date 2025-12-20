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

log_info ">>> STARTING COCKPIT MANAGEMENT CONSOLE INSTALLATION <<<"
detect_os

# --- INSTALLATION ---
if [ "$PACKAGE_MANAGER" == "apt" ]; then
    run_sudo apt-get update
    run_sudo apt-get install -y cockpit
elif [ "$PACKAGE_MANAGER" == "yum" ]; then
    run_sudo yum install -y cockpit
fi

# --- CONFIGURATION ---
log_info "Enabling Cockpit Socket..."
run_sudo systemctl enable --now cockpit.socket

# --- FIREWALL ---
log_info "Configuring Firewall for Cockpit..."
open_port 9090 "Cockpit Management HTTPS"

log_info "Cockpit installed. Login at https://YOUR_IP:9090 with your SSH user/pass."