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

log_info ">>> STARTING WIREGUARD VPN INSTALLATION <<<"

require_docker

# Get Public IP automatically to configure the VPN
PUBLIC_IP=$(curl -s ifconfig.me)

# Manage Credentials
manage_credentials "wireguard" "WG_PASSWORD"

log_info "Detected Public IP: $PUBLIC_IP"

log_info "Deploying WireGuard (WG-Easy)..."
# Note: Wireguard needs UDP port 51820 and CAP_NET_ADMIN capability
run_sudo docker run -d \
  --name=wg-easy \
  -e WG_HOST=$PUBLIC_IP \
  -e PASSWORD="$WG_PASSWORD" \
  -v ~/.wg-easy:/etc/wireguard \
  -p 51820:51820/udp \
  -p 51821:51821/tcp \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --sysctl="net.ipv4.ip_forward=1" \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy

# --- FIREWALL ---
open_port 51820 "WireGuard VPN Traffic" "udp"
open_port 51821 "WireGuard Web UI" "tcp"

log_info "WireGuard Installed."
log_info "   - Web UI: http://$PUBLIC_IP:51821"
log_info "   - Password: $WG_PASSWORD"