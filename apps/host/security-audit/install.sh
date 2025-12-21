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

log_info ">>> STARTING SECURITY TOOLS INSTALLATION (Lynis, RKHunter, ClamAV) <<<"
detect_os

# --- INSTALLATION ---
if [ "$PACKAGE_MANAGER" == "apt" ]; then
    run_sudo apt-get update
    run_sudo apt-get install -y lynis rkhunter clamav clamav-daemon
elif [ "$PACKAGE_MANAGER" == "yum" ]; then
    run_sudo yum install -y epel-release
    run_sudo yum install -y lynis rkhunter clamav clamav-update
fi

# --- CONFIGURATION ---

# 1. Update ClamAV Database
log_info "Updating Antivirus Definitions (might take a minute)..."
run_sudo systemctl stop clamav-freshclam # Stop service to update manually first
run_sudo freshclam
run_sudo systemctl start clamav-freshclam
run_sudo systemctl enable clamav-freshclam

# 2. RKHunter Baseline
log_info "Updating Rootkit Hunter properties..."
# This tells RKHunter "The current state of files is the correct one"
run_sudo rkhunter --propupd

# 3. Lynis Audit Run (Optional - just to show it works)
log_info "Tools installed. To run a full security audit, use: 'sudo lynis audit system'"

log_info "Security Stack Installed."
log_info "   - Run 'sudo clamscan -r /home' to scan for viruses"
log_info "   - Run 'sudo rkhunter --check' to check for rootkits"