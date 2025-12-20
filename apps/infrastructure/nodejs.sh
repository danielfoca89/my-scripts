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

log_info ">>> STARTING NODE.JS (LTS) INSTALLATION <<<"
detect_os

# --- INSTALLATION ---
if [ "$PACKAGE_MANAGER" == "apt" ]; then
    # Install NodeSource Repo (LTS Version 20.x)
    run_sudo apt-get update
    run_sudo apt-get install -y ca-certificates curl gnupg
    run_sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | run_sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    
    NODE_MAJOR=20
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | run_sudo tee /etc/apt/sources.list.d/nodesource.list
    
    run_sudo apt-get update
    run_sudo apt-get install -y nodejs build-essential

elif [ "$PACKAGE_MANAGER" == "yum" ]; then
    run_sudo curl -fsSL https://rpm.nodesource.com/setup_20.x | run_sudo bash -
    run_sudo yum install -y nodejs gcc-c++ make
fi

# --- TOOLING & SECURITY ---

log_info "Installing PM2 (Process Manager)..."
# We install PM2 globally to manage apps so they restart on reboot
run_sudo npm install -g pm2

log_info "Configuring Startup System..."
# Setup PM2 to start on boot
# Note: running 'pm2 startup' generates a command that must be run as root.
# We execute that logic automatically.
PM2_CMD=$(pm2 startup | grep "sudo env")
if [ -n "$PM2_CMD" ]; then
    run_sudo $PM2_CMD
fi

log_info "Node.js $(node -v) & PM2 installed."
log_info "Tip: Never run your Node apps as root. Use this user."