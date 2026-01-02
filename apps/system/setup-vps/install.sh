#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/os-detect.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APP_NAME="setup-vps"

log_info "VPS Initial Setup..."
log_info "This is a workflow, not an app installation."

if [ -f "$SCRIPT_DIR/workflows/vps-initial-setup.sh" ]; then
    log_info "Running VPS initial setup workflow..."
    bash "$SCRIPT_DIR/workflows/vps-initial-setup.sh"
else
    log_error "Workflow script not found"
    exit 1
fi
