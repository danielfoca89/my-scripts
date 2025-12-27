#!/bin/bash
# ==============================================================================
# PORTAINER DOCKER UI INSTALLATION
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APP_NAME="portainer"
CONTAINER_NAME="portainer"
DATA_DIR="/opt/infrastructure/portainer"

log_info "═══════════════════════════════════════════"
log_info "  Installing Portainer Docker UI"
log_info "═══════════════════════════════════════════"
echo ""

log_step "Step 1: Checking dependencies"
if ! check_docker; then
    log_error "Docker is not installed"
    log_info "Please install Docker first: Infrastructure > Docker Engine"
    exit 1
fi
log_success "Docker is available"
echo ""

if run_sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warn "Portainer container already exists"
    if confirm_action "Do you want to reinstall Portainer?"; then
        log_info "Stopping and removing existing container..."
        run_sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
        run_sudo docker rm "$CONTAINER_NAME" 2>/dev/null || true
    else
        log_info "Installation cancelled"
        exit 0
    fi
fi

log_step "Step 2: Setting up directories"
create_app_directory "$DATA_DIR/data"
log_success "Data directory created: $DATA_DIR"
echo ""

log_step "Step 3: Setting up Docker network"
create_docker_network "vps_network"
echo ""

log_step "Step 4: Deploying Portainer container"
log_info "Starting Portainer CE..."

run_sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${DATA_DIR}/data:/data" \
    -p 9000:9000 \
    -p 9443:9443 \
    portainer/portainer-ce:latest

log_success "Portainer container started"
echo ""

log_step "Step 5: Waiting for Portainer to be ready"
log_info "This may take 30-45 seconds..."
check_container_health "$CONTAINER_NAME" 40
echo ""

init_secrets_dir
save_secret "$APP_NAME" "PORTAINER_URL" "https://$(hostname -I | awk '{print $1}'):9443"

log_success "═══════════════════════════════════════════"
log_success "  Portainer Installation Complete!"
log_success "═══════════════════════════════════════════"
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')
log_info "Access Information:"
echo "  HTTP:  http://${SERVER_IP}:9000"
echo "  HTTPS: https://${SERVER_IP}:9443 (recommended)"
echo ""

log_warn "IMPORTANT - First Time Setup:"
echo "  1. Open Portainer in your browser"
echo "  2. Create an admin account (within 5 minutes!)"
echo "  3. Select 'Docker' as environment"
echo ""

log_info "Useful commands:"
echo "  docker logs portainer    # View logs"
echo "  docker restart portainer # Restart"
echo ""
read -p "Press Enter to continue..."
