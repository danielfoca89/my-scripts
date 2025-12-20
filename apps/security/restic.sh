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

log_info ">>> STARTING RESTIC BACKUP TOOL INSTALLATION <<<"
detect_os

# --- INSTALLATION ---
if [ "$PACKAGE_MANAGER" == "apt" ]; then
    run_sudo apt-get update
    run_sudo apt-get install -y restic
elif [ "$PACKAGE_MANAGER" == "yum" ]; then
    # Restic is usually in EPEL
    run_sudo yum install -y epel-release
    run_sudo yum install -y restic
fi

# --- VERIFICATION ---
if command -v restic >/dev/null; then
    VERSION=$(restic version)
    log_info "Restic installed successfully: $VERSION"
    log_info "   - Next step: Initialize a repo (e.g., 'restic init --repo /tmp/backup')"
    log_info "   - Documentation: https://restic.readthedocs.io/"
else
    log_error "Restic installation failed."
    exit 1
fi