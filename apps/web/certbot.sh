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

log_info ">>> STARTING CERTBOT (SSL) INSTALLATION <<<"
detect_os

if [ "$PACKAGE_MANAGER" == "apt" ]; then
    run_sudo apt-get update
    run_sudo apt-get install -y certbot python3-certbot-nginx
elif [ "$PACKAGE_MANAGER" == "yum" ]; then
    run_sudo yum install -y certbot python3-certbot-nginx
fi

log_info "Testing Certbot renewal mechanism..."
# We run a dry-run to ensure the communication with Let's Encrypt works
run_sudo certbot renew --dry-run

log_info "Certbot installed. usage: 'sudo certbot --nginx -d yourdomain.com'"