#!/bin/bash

# ==============================================================================
# N8N WORKFLOW AUTOMATION PLATFORM
# Self-hosted workflow automation with 300+ integrations
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APP_NAME="n8n"
CONTAINER_NAME="n8n"
DATA_DIR="/opt/automation/n8n"
NETWORK="vps_network"

log_info "═══════════════════════════════════════════"
log_info "  Installing n8n Workflow Automation"
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

# Check for PostgreSQL (optional but recommended)
POSTGRES_AVAILABLE=false
if docker ps --format '{{.Names}}' | grep -q "^postgres$"; then
    POSTGRES_AVAILABLE=true
    log_success "PostgreSQL detected - will use for persistent storage"
else
    log_warn "PostgreSQL not detected - using SQLite (not recommended for production)"
    log_info "For production, install PostgreSQL first: Databases > PostgreSQL"
fi
echo ""

# Check for existing installation
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warn "n8n is already installed"
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

# Generate credentials
log_step "Step 2: Generating secure credentials"
if ! has_credentials "$APP_NAME"; then
    N8N_USER="admin@n8n.local"
    N8N_PASSWORD=$(generate_secure_password)
    N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
    
    save_secret "$APP_NAME" "N8N_USER" "$N8N_USER"
    save_secret "$APP_NAME" "N8N_PASSWORD" "$N8N_PASSWORD"
    save_secret "$APP_NAME" "N8N_ENCRYPTION_KEY" "$N8N_ENCRYPTION_KEY"
    
    log_success "Credentials generated securely"
else
    log_info "Using existing credentials"
    N8N_USER=$(get_secret "$APP_NAME" "N8N_USER")
    N8N_PASSWORD=$(get_secret "$APP_NAME" "N8N_PASSWORD")
    N8N_ENCRYPTION_KEY=$(get_secret "$APP_NAME" "N8N_ENCRYPTION_KEY")
fi
echo ""

# Setup directories
log_step "Step 3: Setting up directories"
create_app_directory "$DATA_DIR"
create_app_directory "$DATA_DIR/.n8n"
log_success "n8n directories created"
echo ""

# Create Docker network
log_step "Step 4: Creating Docker network"
create_docker_network "$NETWORK"
echo ""

# Create Docker Compose file
log_step "Step 5: Creating Docker Compose configuration"

if [ "$POSTGRES_AVAILABLE" = true ]; then
    # PostgreSQL configuration
    POSTGRES_PASSWORD=$(get_secret "postgres" "POSTGRES_PASSWORD")
    N8N_DB_NAME="n8n"
    
    # Create database if it doesn't exist
    log_info "Creating PostgreSQL database..."
    docker exec postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$N8N_DB_NAME'" | grep -q 1 || \
        docker exec postgres psql -U postgres -c "CREATE DATABASE $N8N_DB_NAME;"
    
    cat > "$DATA_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      # Database (PostgreSQL)
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=$N8N_DB_NAME
      - DB_POSTGRESDB_USER=postgres
      - DB_POSTGRESDB_PASSWORD=$POSTGRES_PASSWORD
      
      # Encryption
      - N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
      
      # Basic Auth
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=$N8N_USER
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
      
      # General settings
      - N8N_HOST=\${N8N_HOST:-localhost}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=\${WEBHOOK_URL:-http://localhost:5678/}
      - GENERIC_TIMEZONE=\${TZ:-Europe/Bucharest}
      
      # Execution
      - EXECUTIONS_PROCESS=main
      - EXECUTIONS_MODE=regular
      
      # Logs
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      
    volumes:
      - $DATA_DIR/.n8n:/home/node/.n8n
      
    networks:
      - $NETWORK
      
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  $NETWORK:
    external: true
EOF
else
    # SQLite configuration (default)
    cat > "$DATA_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      # Encryption
      - N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
      
      # Basic Auth
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=$N8N_USER
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
      
      # General settings
      - N8N_HOST=\${N8N_HOST:-localhost}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=\${WEBHOOK_URL:-http://localhost:5678/}
      - GENERIC_TIMEZONE=\${TZ:-Europe/Bucharest}
      
      # Execution
      - EXECUTIONS_PROCESS=main
      - EXECUTIONS_MODE=regular
      
      # Logs
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      
    volumes:
      - $DATA_DIR/.n8n:/home/node/.n8n
      
    networks:
      - $NETWORK
      
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  $NETWORK:
    external: true
EOF
fi

log_success "Docker Compose configuration created"
echo ""

# Deploy container
log_step "Step 6: Deploying n8n container"
if ! deploy_with_compose "$DATA_DIR"; then
    log_error "Failed to deploy n8n"
    exit 1
fi
echo ""

# Wait for container to be ready
log_step "Step 7: Waiting for n8n to be ready"
RETRIES=60
COUNT=0
while [ $COUNT -lt $RETRIES ]; do
    if docker exec $CONTAINER_NAME wget --no-verbose --tries=1 --spider http://localhost:5678/healthz 2>/dev/null; then
        log_success "n8n is ready!"
        break
    fi
    COUNT=$((COUNT + 1))
    if [ $COUNT -eq $RETRIES ]; then
        log_error "n8n failed to become ready"
        docker logs $CONTAINER_NAME --tail 50
        exit 1
    fi
    sleep 2
done
echo ""

# Display connection info
log_success "═══════════════════════════════════════════"
log_success "  n8n Installation Complete!"
log_success "═══════════════════════════════════════════"
echo ""

display_connection_info "$APP_NAME" "N8N_USER" "N8N_PASSWORD"
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')
log_info "🌐 Access URLs:"
echo "  Local:    http://localhost:5678"
echo "  Network:  http://$SERVER_IP:5678"
echo ""

if [ "$POSTGRES_AVAILABLE" = true ]; then
    log_info "💾 Database:"
    echo "  Type: PostgreSQL"
    echo "  Database: $N8N_DB_NAME"
    echo "  ✅ Production-ready persistent storage"
else
    log_warn "💾 Database:"
    echo "  Type: SQLite"
    echo "  ⚠️  Not recommended for production"
    echo "  Consider installing PostgreSQL for better performance"
fi
echo ""

log_info "🔑 Security:"
echo "  • Basic authentication enabled"
echo "  • Data encryption active"
echo "  • Credentials stored in: ~/.vps-secrets/$APP_NAME.env"
echo ""

log_info "📦 Docker management:"
echo "  View logs:    docker logs $CONTAINER_NAME -f"
echo "  Restart:      docker restart $CONTAINER_NAME"
echo "  Stop:         docker stop $CONTAINER_NAME"
echo "  Start:        docker start $CONTAINER_NAME"
echo "  Remove:       cd $DATA_DIR && docker-compose down"
echo ""

log_info "🔄 Workflow examples:"
echo "  • Schedule tasks (cron-based triggers)"
echo "  • Webhook automation (HTTP requests)"
echo "  • Email notifications (SMTP integration)"
echo "  • Database operations (SQL queries)"
echo "  • API integrations (300+ services)"
echo "  • File processing (CSV, JSON, XML)"
echo ""

log_info "🔗 Popular integrations:"
echo "  • Slack, Discord, Telegram"
echo "  • Google Sheets, Drive, Calendar"
echo "  • GitHub, GitLab"
echo "  • PostgreSQL, MySQL, MongoDB"
echo "  • HTTP Request, Webhook"
echo "  • Cron (scheduled workflows)"
echo ""

log_warn "⚠️  Important notes:"
echo "  • For production, use HTTPS (configure Nginx reverse proxy)"
echo "  • Webhook URL should be accessible from internet"
echo "  • Regular backups: $DATA_DIR/.n8n/"
echo "  • Monitor executions in n8n dashboard"
echo ""

log_info "💡 Next steps:"
echo "  1. Access n8n web interface"
echo "  2. Login with generated credentials"
echo "  3. Create your first workflow"
echo "  4. Test with simple HTTP request node"
echo "  5. Configure webhook URL if needed"
echo "  6. Setup Nginx reverse proxy for HTTPS (recommended)"
echo ""

log_info "📚 Documentation:"
echo "  • Official docs: https://docs.n8n.io"
echo "  • Workflow templates: https://n8n.io/workflows"
echo "  • Community: https://community.n8n.io"
echo ""

read -p "Press Enter to continue..."

