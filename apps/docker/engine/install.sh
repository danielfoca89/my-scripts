#!/bin/bash

# Import Library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve utils.sh location (it is now in ../../../lib/utils.sh relative to apps/docker/engine/install.sh)
if [ -f "$SCRIPT_DIR/../../../lib/utils.sh" ]; then
    source "$SCRIPT_DIR/../../../lib/utils.sh"
elif [ -f "/tmp/lib/utils.sh" ]; then
    source "/tmp/lib/utils.sh"
else
    echo "Error: utils.sh not found."
    exit 1
fi

log_info ">>> STARTING DOCKER INSTALLATION & SECURITY SETUP <<<"
detect_os

# --- CHECK IF INSTALLED ---
if command -v docker >/dev/null; then
    log_info "Docker is already installed. Skipping installation."
    exit 0
fi

# --- INSTALLATION ---
if [ "$PACKAGE_MANAGER" == "apt" ]; then
    log_info "Installing Docker via APT (Base: $PARENT_OS)..."
    run_sudo apt-get update
    run_sudo apt-get install -y ca-certificates curl gnupg
    
    # Keyring setup
    run_sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$PARENT_OS/gpg | run_sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    run_sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Repo setup
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$PARENT_OS \
      $PARENT_CODENAME stable" | \
      run_sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      
    run_sudo apt-get update
    run_sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

elif [ "$PACKAGE_MANAGER" == "yum" ]; then
    log_info "Installing Docker via YUM..."
    run_sudo yum install -y yum-utils
    run_sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    run_sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# --- CONFIGURATION & SECURITY ---

log_info "Configuring Docker Security Standards..."

# 1. Enable Service
run_sudo systemctl enable docker
run_sudo systemctl start docker

# 2. Add current user to Docker group (Convenience)
CURRENT_USER=$(whoami)
run_sudo usermod -aG docker "$CURRENT_USER"
log_info "User $CURRENT_USER added to 'docker' group."

# 3. Configure Daemon Logging (Prevent disk exhaustion)
# By default, Docker logs can grow infinitely. We limit them.
log_info "Setting Docker Logging limits (daemon.json)..."
cat <<EOF | run_sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart to apply logging limits
run_sudo systemctl restart docker

log_info "Docker installation and hardening complete."