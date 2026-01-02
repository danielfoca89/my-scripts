#!/bin/bash

# ==============================================================================
# POSTGRESQL DATABASE INSTALLATION
# Deploys PostgreSQL in Docker container with auto-generated credentials
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/os-detect.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/preflight.sh"

APP_NAME="postgres"
CONTAINER_NAME="postgres"
DATA_DIR="/opt/databases/postgres"

log_info "═══════════════════════════════════════════"
log_info "  Installing PostgreSQL Database"
log_info "═══════════════════════════════════════════"
echo ""

audit_log "INSTALL_START" "$APP_NAME"

# Pre-flight checks
preflight_check "$APP_NAME" 15 2 "5432"

# Check dependency
log_step "Step 1: Checking dependencies"
if ! check_docker; then
    log_error "Docker dependency check failed"
    exit 1
fi

# Generate or load credentials
log_step "Step 2: Managing credentials"
init_secrets_dir

if has_credentials "$APP_NAME"; then
    log_info "Loading existing credentials..."
    load_secrets "$APP_NAME"
else
    log_info "Generating new credentials..."
    
    # Generate secure password and random credentials
    DB_PASSWORD=$(generate_secure_password 32 "alphanumeric")
    POSTGRES_USER="user_$(generate_secure_password 12 'alphanumeric' | tr '[:upper:]' '[:lower:]')"
    POSTGRES_DB="db_$(generate_secure_password 12 'alphanumeric' | tr '[:upper:]' '[:lower:]')"
    
    # Save credentials
    save_secret "$APP_NAME" "DB_PASSWORD" "$DB_PASSWORD"
    save_secret "$APP_NAME" "POSTGRES_USER" "$POSTGRES_USER"
    save_secret "$APP_NAME" "POSTGRES_DB" "$POSTGRES_DB"
    
    # Load for current session
    load_secrets "$APP_NAME"
fi

# Create network
log_step "Step 3: Setting up Docker network"
create_docker_network "vps_network"

# Create directories
log_step "Step 4: Creating data directories"
create_app_directory "$DATA_DIR/data" 755

# Check if already installed
if run_sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if run_sudo docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_warn "Postgres container is already running"
        if confirm_action "Reinstall? (This will stop the DB and remove container)"; then
            log_info "Stopping and removing existing container..."
            remove_container "$CONTAINER_NAME"
        else
            log_info "Installation cancelled"
            echo ""
            log_info "Connection String (external):"
            SERVER_IP=$(hostname -I | awk '{print $1}')
            echo "  postgresql://${POSTGRES_USER}:[PASSWORD]@${SERVER_IP}:5432/${POSTGRES_DB}"
            exit 0
        fi
    else
        log_warn "Postgres container exists but is STOPPED"
        if confirm_action "Start Postgres instead of reinstalling?"; then
             log_info "Starting Postgres..."
             run_sudo docker start "$CONTAINER_NAME"
             log_success "Postgres started successfully"
             exit 0
        else
            log_info "Removing old container to reinstall..."
            remove_container "$CONTAINER_NAME"
        fi
    fi
fi

# Deploy container
log_step "Step 5: Deploying PostgreSQL container"
log_info "Using image: postgres:16-alpine"

run_sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    --cpus="2" \
    --memory="2g" \
    --memory-reservation="512m" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v "${DATA_DIR}/data":/var/lib/postgresql/data \
    -p 5432:5432 \
    --health-cmd="pg_isready -U ${POSTGRES_USER}" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=5 \
    postgres:16-alpine

# Check health
log_step "Step 6: Verifying installation"
if check_container_health "$CONTAINER_NAME" 30; then
    log_success "PostgreSQL is running and healthy!"
else
    log_error "PostgreSQL health check failed"
    show_container_logs "$CONTAINER_NAME" 20
    exit 1
fi

# Configure firewall (optional, typically accessed via Docker network)
# open_port 5432 "PostgreSQL Database"

echo ""
log_success "═══════════════════════════════════════════"
log_success "  PostgreSQL installed successfully!"
log_success "═══════════════════════════════════════════"
echo ""

# Display connection information
log_info "Container Details:"
echo "  Name:       $CONTAINER_NAME"
echo "  Network:    vps_network"
echo "  Port:       5432"
echo "  Data Dir:   $DATA_DIR/data"
echo ""

log_info "Connection String (from Docker network):"
echo "  Host:     postgres"
echo "  Port:     5432"
echo "  User:     $POSTGRES_USER"
echo "  Database: $POSTGRES_DB"
echo ""

log_info "Connection String (external):"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "  postgresql://${POSTGRES_USER}:[PASSWORD]@${SERVER_IP}:5432/${POSTGRES_DB}"
echo ""

log_warn "Security Note:"
echo "  • Credentials are stored in: ~/.vps-secrets/.env_${APP_NAME}"
echo "  • For external access, ensure firewall allows port 5432"
echo "  • Consider using SSL/TLS for production"
echo ""

log_info "Management Commands:"
echo "  View logs:    docker logs $CONTAINER_NAME"
echo "  Connect:      docker exec -it $CONTAINER_NAME psql -U $POSTGRES_USER"
echo "  Restart:      docker restart $CONTAINER_NAME"
echo "  Stop:         docker stop $CONTAINER_NAME"
echo "  Remove:       docker rm -f $CONTAINER_NAME"
echo ""
