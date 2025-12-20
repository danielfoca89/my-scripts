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

log_info ">>> STARTING NETDATA MONITORING INSTALLATION <<<"

# Netdata has a specialized one-line installer that works on all distros
# We use the official kickstart script
log_info "Downloading and running Netdata Kickstart..."

# Disable telemetry and non-interactive mode
wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh
run_sudo sh /tmp/netdata-kickstart.sh --non-interactive --stable-channel --disable-telemetry

# --- FIREWALL ---
log_info "Configuring Firewall for Netdata Dashboard..."
open_port 19999 "Netdata Monitoring Dashboard"

log_info "Netdata installed. Dashboard available at http://YOUR_IP:19999"