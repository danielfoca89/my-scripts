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

log_info ">>> CONFIGURING ADDITIONAL LOG MAINTENANCE <<<"

# Create a custom logrotate for Docker containers (if not handled by daemon.json)
# This is a fallback/safety measure
log_info "Setting up Docker Log Rotation rule..."

cat <<EOF | run_sudo tee /etc/logrotate.d/docker-containers
/var/lib/docker/containers/*/*.log {
  rotate 7
  daily
  compress
  missingok
  delaycompress
  copytruncate
}
EOF

# Install ncdu (NCurses Disk Usage) - essential tool to find what eats disk space
detect_os
if [ "$PACKAGE_MANAGER" == "apt" ]; then
    run_sudo apt-get install -y ncdu
elif [ "$PACKAGE_MANAGER" == "yum" ]; then
    run_sudo yum install -y ncdu
fi

log_info "Log maintenance configured & NCDU tool installed."