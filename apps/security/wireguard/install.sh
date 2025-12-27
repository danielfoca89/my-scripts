#!/bin/bash

# ==============================================================================
# WIREGUARD VPN SERVER
# Modern, fast, and secure VPN with easy peer management
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APP_NAME="wireguard"
CONTAINER_NAME="wireguard"
DATA_DIR="/opt/security/wireguard"
NETWORK="vps_network"

log_info "═══════════════════════════════════════════"
log_info "  Installing WireGuard VPN Server"
log_info "═══════════════════════════════════════════"
echo ""

# Check dependencies
log_step "Step 1: Checking dependencies"
if ! check_docker; then
    log_error "Docker is not installed"
    log_info "Please install Docker first: Infrastructure > Docker Engine"
    exit 1
fi
log_success "Docker is available"

# Check for qrencode
if ! command -v qrencode &> /dev/null; then
    log_warn "qrencode not installed - QR codes won't be generated"
    log_info "Install with: apt install qrencode or yum install qrencode"
else
    log_success "qrencode available for QR code generation"
fi
echo ""

# Check for existing installation
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warn "WireGuard is already installed"
    if confirm_action "Reinstall?"; then
        log_info "Removing existing installation..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    else
        log_info "Installation cancelled"
        exit 0
    fi
fi
echo ""

# Get server configuration
log_step "Step 2: Configuring WireGuard server"
SERVER_IP=$(hostname -I | awk '{print $1}')

log_info "Server IP detected: $SERVER_IP"
read -p "Enter server public IP/domain [$SERVER_IP]: " USER_SERVER_URL
SERVER_URL="${USER_SERVER_URL:-$SERVER_IP}"

read -p "Number of peers to create [3]: " USER_PEERS
PEERS="${USER_PEERS:-3}"

log_success "Server URL: $SERVER_URL"
log_success "Creating $PEERS peer configurations"
echo ""

# Setup directories
log_step "Step 3: Setting up directories"
create_app_directory "$DATA_DIR"
create_app_directory "$DATA_DIR/config"
log_success "WireGuard directories created"
echo ""

# Create Docker network
log_step "Step 4: Creating Docker network"
create_docker_network "$NETWORK"
echo ""

# Deploy WireGuard container
log_step "Step 5: Deploying WireGuard VPN server"
log_info "This requires elevated privileges for networking..."

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network "$NETWORK" \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_MODULE \
    --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ=Europe/Bucharest \
    -e SERVERURL="$SERVER_URL" \
    -e SERVERPORT=51820 \
    -e PEERS="$PEERS" \
    -e PEERDNS=auto \
    -e INTERNAL_SUBNET=10.13.13.0 \
    -e ALLOWEDIPS=0.0.0.0/0 \
    -e LOG_CONFS=true \
    -v "$DATA_DIR/config:/config" \
    -v /lib/modules:/lib/modules:ro \
    -p 51820:51820/udp \
    linuxserver/wireguard:latest

if [ $? -ne 0 ]; then
    log_error "Failed to deploy WireGuard"
    exit 1
fi
log_success "Container deployed"
echo ""

# Wait for configuration generation
log_step "Step 6: Waiting for peer configurations"
log_info "Generating peer configurations and keys..."
sleep 15

RETRIES=30
COUNT=0
while [ $COUNT -lt $RETRIES ]; do
    if [ -f "$DATA_DIR/config/peer1/peer1.conf" ]; then
        log_success "Peer configurations ready!"
        break
    fi
    COUNT=$((COUNT + 1))
    if [ $COUNT -eq $RETRIES ]; then
        log_error "Peer configuration generation timeout"
        docker logs $CONTAINER_NAME --tail 50
        exit 1
    fi
    sleep 2
done
echo ""

# Create peer management script
log_step "Step 7: Creating peer management script"
cat > "$DATA_DIR/manage-peers.sh" << 'EOFSCRIPT'
#!/bin/bash
set -e

CONFIG_DIR="/opt/security/wireguard/config"

case "$1" in
    list)
        echo "WireGuard Peers:"
        for peer in "$CONFIG_DIR"/peer*/peer*.conf; do
            [ -f "$peer" ] && basename "$(dirname "$peer")"
        done
        ;;
    show)
        [ -z "$2" ] && echo "Usage: $0 show <peer_number>" && exit 1
        PEER="peer$2"
        if [ -f "$CONFIG_DIR/$PEER/$PEER.conf" ]; then
            echo "Configuration for $PEER:"
            cat "$CONFIG_DIR/$PEER/$PEER.conf"
            echo ""
            if [ -f "$CONFIG_DIR/$PEER/$PEER.png" ]; then
                echo "QR Code: $CONFIG_DIR/$PEER/$PEER.png"
            fi
        else
            echo "Peer $2 not found"
            exit 1
        fi
        ;;
    qr)
        [ -z "$2" ] && echo "Usage: $0 qr <peer_number>" && exit 1
        PEER="peer$2"
        if [ -f "$CONFIG_DIR/$PEER/$PEER.conf" ]; then
            if command -v qrencode &> /dev/null; then
                qrencode -t ansiutf8 < "$CONFIG_DIR/$PEER/$PEER.conf"
            else
                echo "qrencode not installed"
                echo "Install: apt install qrencode"
            fi
        else
            echo "Peer $2 not found"
            exit 1
        fi
        ;;
    *)
        echo "WireGuard Peer Management"
        echo "Usage: $0 {list|show|qr} [peer_number]"
        echo ""
        echo "Commands:"
        echo "  list         - List all peers"
        echo "  show <N>     - Show peer N configuration"
        echo "  qr <N>       - Display QR code for peer N"
        ;;
esac
EOFSCRIPT

chmod +x "$DATA_DIR/manage-peers.sh"
log_success "Peer management script created"
echo ""

# Display installation summary
log_success "═══════════════════════════════════════════"
log_success "  WireGuard VPN Installation Complete!"
log_success "═══════════════════════════════════════════"
echo ""

log_info "🌐 Server details:"
echo "  Server URL:   $SERVER_URL"
echo "  Server Port:  51820/UDP"
echo "  VPN Subnet:   10.13.13.0/24"
echo "  Peers:        $PEERS"
echo ""

log_info "📁 Configuration files:"
echo "  Location: $DATA_DIR/config/"
for i in $(seq 1 $PEERS); do
    echo "  peer$i:   $DATA_DIR/config/peer$i/peer$i.conf"
    [ -f "$DATA_DIR/config/peer$i/peer$i.png" ] && echo "           $DATA_DIR/config/peer$i/peer$i.png (QR)"
done
echo ""

log_info "🔧 Peer management:"
echo "  List peers:        sudo $DATA_DIR/manage-peers.sh list"
echo "  Show config:       sudo $DATA_DIR/manage-peers.sh show <N>"
echo "  Display QR code:   sudo $DATA_DIR/manage-peers.sh qr <N>"
echo ""

log_info "📦 Docker management:"
echo "  View logs:    docker logs $CONTAINER_NAME -f"
echo "  Restart:      docker restart $CONTAINER_NAME"
echo "  Stop:         docker stop $CONTAINER_NAME"
echo "  Remove:       docker rm -f $CONTAINER_NAME"
echo ""

log_info "📱 Client setup:"
echo "  1. Install WireGuard client on device:"
echo "     - Android/iOS: WireGuard app from store"
echo "     - Windows/Mac/Linux: https://www.wireguard.com/install/"
echo ""
echo "  2. Import configuration:"
echo "     - Scan QR code from peer*.png files"
echo "     - Or copy peer*.conf manually"
echo ""
echo "  3. Activate connection in WireGuard client"
echo ""

log_warn "⚠️  Important notes:"
echo "  • Port 51820/UDP must be open in firewall"
echo "  • Enable IP forwarding (already configured by container)"
echo "  • Each peer has unique keys - never share between devices"
echo "  • Configuration files contain private keys - keep secure"
echo "  • To add more peers, recreate container with higher PEERS value"
echo ""

log_info "🔥 Firewall configuration:"
echo "  UFW:      sudo ufw allow 51820/udp"
echo "  firewalld: sudo firewall-cmd --add-port=51820/udp --permanent"
echo "  iptables: sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT"
echo ""

log_info "💡 Next steps:"
echo "  1. Ensure firewall allows UDP port 51820"
echo "  2. List available peers: sudo $DATA_DIR/manage-peers.sh list"
echo "  3. View peer configuration or QR code"
echo "  4. Install WireGuard client on devices"
echo "  5. Import configuration and connect"
echo "  6. Test connection: ping 10.13.13.1"
echo ""

read -p "Press Enter to continue..."

