#!/bin/bash

# ==============================================================================
# N8N WORKFLOW AUTOMATION PLATFORM
# Self-hosted workflow automation with 300+ integrations
# Includes: Domain configuration, SSL certificate, PostgreSQL database
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

# Docker check
if ! check_docker; then
    log_error "Docker is not installed"
    log_info "Please install Docker first: Infrastructure > Docker Engine"
    exit 1
fi
log_success "✓ Docker is available"

# PostgreSQL check (REQUIRED)
POSTGRES_AVAILABLE=false
if run_sudo docker ps --format '{{.Names}}' | grep -q "^postgres$"; then
    POSTGRES_AVAILABLE=true
    log_success "✓ PostgreSQL detected"
else
    log_error "PostgreSQL is not installed"
    log_info "PostgreSQL is REQUIRED for n8n production deployment"
    log_info "Please install PostgreSQL first: Databases > PostgreSQL"
    exit 1
fi

# Nginx check (REQUIRED for SSL)
if ! run_sudo systemctl is-active --quiet nginx 2>/dev/null; then
    log_error "Nginx is not installed"
    log_info "Nginx is REQUIRED for SSL certificate and reverse proxy"
    log_info "Please install Nginx first: Infrastructure > Nginx"
    exit 1
fi
log_success "✓ Nginx is available"

# Certbot check (REQUIRED for SSL)
if ! command -v certbot &>/dev/null; then
    log_error "Certbot is not installed"
    log_info "Certbot is REQUIRED for SSL certificates"
    log_info "Please install Certbot first: Infrastructure > Certbot"
    exit 1
fi
log_success "✓ Certbot is available"
echo ""

# Check for existing installation
if run_sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_success "✓ n8n is already installed"
    if confirm_action "Reinstall?"; then
        log_info "Removing existing installation..."
        run_sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
        run_sudo docker rm "$CONTAINER_NAME" 2>/dev/null || true
    else
        log_info "Installation cancelled"
        exit 0
    fi
fi
echo ""

# Domain and email configuration
log_step "Step 2: Domain and SSL configuration"
echo ""
log_info "n8n requires a domain name for SSL certificate"
log_info "Example: work.venditax.com"
echo ""

# Domain prompt
while true; do
    read -p "Enter your domain name: " N8N_DOMAIN
    N8N_DOMAIN=$(echo "$N8N_DOMAIN" | xargs) # trim whitespace
    
    if [ -z "$N8N_DOMAIN" ]; then
        log_error "Domain cannot be empty"
        continue
    fi
    
    # Basic domain validation
    if [[ ! "$N8N_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid domain format"
        continue
    fi
    
    log_success "Domain: $N8N_DOMAIN"
    break
done
echo ""

# Email prompt
log_info "SSL certificate requires an email address for notifications"
log_info "Example: admin@venditax.com"
echo ""

while true; do
    read -p "Enter your email address: " N8N_EMAIL
    N8N_EMAIL=$(echo "$N8N_EMAIL" | xargs) # trim whitespace
    
    if [ -z "$N8N_EMAIL" ]; then
        log_error "Email cannot be empty"
        continue
    fi
    
    # Basic email validation
    if [[ ! "$N8N_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid email format"
        continue
    fi
    
    log_success "Email: $N8N_EMAIL"
    break
done

# Save domain and email
save_secret "$APP_NAME" "N8N_DOMAIN" "$N8N_DOMAIN"
save_secret "$APP_NAME" "N8N_EMAIL" "$N8N_EMAIL"
echo ""

# Generate credentials
log_step "Step 3: Generating secure credentials"
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

# Create PostgreSQL database and user
log_step "Step 4: Creating PostgreSQL database"
POSTGRES_PASSWORD=$(get_secret "postgres" "POSTGRES_PASSWORD")
N8N_DB_NAME="n8n_db"
N8N_DB_USER="n8n_user"
N8N_DB_PASSWORD=$(generate_secure_password)

log_info "Creating database: $N8N_DB_NAME"

# Create database
run_sudo docker exec postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$N8N_DB_NAME'" | grep -q 1 || \
    run_sudo docker exec postgres psql -U postgres -c "CREATE DATABASE $N8N_DB_NAME;"

# Create user
run_sudo docker exec postgres psql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname = '$N8N_DB_USER'" | grep -q 1 || \
    run_sudo docker exec postgres psql -U postgres -c "CREATE USER $N8N_DB_USER WITH ENCRYPTED PASSWORD '$N8N_DB_PASSWORD';"

# Grant privileges
run_sudo docker exec postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $N8N_DB_NAME TO $N8N_DB_USER;"

# Save database credentials
save_secret "$APP_NAME" "DB_NAME" "$N8N_DB_NAME"
save_secret "$APP_NAME" "DB_USER" "$N8N_DB_USER"
save_secret "$APP_NAME" "DB_PASSWORD" "$N8N_DB_PASSWORD"

log_success "Database created: $N8N_DB_NAME"
log_success "User created: $N8N_DB_USER"
echo ""

# Setup directories
log_step "Step 5: Setting up directories"
create_app_directory "$DATA_DIR"
create_app_directory "$DATA_DIR/.n8n"
log_success "n8n directories created"
echo ""

# Create Docker network
log_step "Step 6: Creating Docker network"
create_docker_network "$NETWORK"
echo ""

# Create Docker Compose file
log_step "Step 7: Creating Docker Compose configuration"

cat > "$DATA_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      # Database (PostgreSQL)
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=$N8N_DB_NAME
      - DB_POSTGRESDB_USER=$N8N_DB_USER
      - DB_POSTGRESDB_PASSWORD=$N8N_DB_PASSWORD
      
      # Encryption
      - N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
      
      # Basic Auth
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=$N8N_USER
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
      
      # Domain and SSL settings
      - N8N_HOST=$N8N_DOMAIN
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://$N8N_DOMAIN/
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

log_success "Docker Compose configuration created"
echo ""

# Deploy container
log_step "Step 8: Deploying n8n container"
if ! deploy_with_compose "$DATA_DIR"; then
    log_error "Failed to deploy n8n"
    exit 1
fi
echo ""

# Wait for container to be ready
log_step "Step 9: Waiting for n8n to be ready"
RETRIES=60
COUNT=0
while [ $COUNT -lt $RETRIES ]; do
    if run_sudo docker exec $CONTAINER_NAME wget --no-verbose --tries=1 --spider http://localhost:5678/healthz 2>/dev/null; then
        log_success "n8n is ready!"
        break
    fi
    COUNT=$((COUNT + 1))
    if [ $COUNT -eq $RETRIES ]; then
        log_error "n8n failed to become ready"
        run_sudo docker logs $CONTAINER_NAME --tail 50
        exit 1
    fi
    sleep 2
done
echo ""

# Configure Nginx reverse proxy
log_step "Step 10: Configuring Nginx reverse proxy"

cat > "/etc/nginx/sites-available/$APP_NAME.conf" << 'EOF_NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name N8N_DOMAIN_PLACEHOLDER;

    # Security headers
    include snippets/security.conf;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect to HTTPS (will be configured after SSL)
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name N8N_DOMAIN_PLACEHOLDER;

    # SSL certificates (will be configured by certbot)
    # ssl_certificate /etc/letsencrypt/live/N8N_DOMAIN_PLACEHOLDER/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/N8N_DOMAIN_PLACEHOLDER/privkey.pem;

    # SSL configuration
    include snippets/ssl-params.conf;
    
    # Security headers
    include snippets/security.conf;

    # Logging
    access_log /var/log/nginx/n8n_access.log;
    error_log /var/log/nginx/n8n_error.log;

    # n8n proxy settings
    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
        # Timeouts (n8n workflows can be long-running)
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF_NGINX

# Replace domain placeholder
run_sudo sed -i "s/N8N_DOMAIN_PLACEHOLDER/$N8N_DOMAIN/g" "/etc/nginx/sites-available/$APP_NAME.conf"

# Enable site
run_sudo ln -sf "/etc/nginx/sites-available/$APP_NAME.conf" "/etc/nginx/sites-enabled/$APP_NAME.conf"

# Test Nginx configuration
if run_sudo nginx -t 2>&1 | grep -q "syntax is ok"; then
    log_success "Nginx configuration is valid"
    run_sudo systemctl reload nginx
    log_success "Nginx reloaded"
else
    log_error "Nginx configuration test failed"
    run_sudo nginx -t
    exit 1
fi
echo ""

# Request SSL certificate
log_step "Step 11: Requesting SSL certificate"
log_info "Requesting certificate from Let's Encrypt..."
log_warn "Make sure your domain DNS points to this server!"
echo ""

# Wait for user to verify DNS
log_info "Press Enter when DNS is configured, or Ctrl+C to cancel"
read -p "" DUMMY

# Request certificate
if run_sudo certbot --nginx -d "$N8N_DOMAIN" \
    --email "$N8N_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --redirect \
    --non-interactive; then
    log_success "SSL certificate installed successfully"
else
    log_error "Failed to obtain SSL certificate"
    log_info "You can manually run: sudo certbot --nginx -d $N8N_DOMAIN"
    log_warn "n8n is running but only accessible via HTTP for now"
fi
echo ""

# Display connection info
log_success "═══════════════════════════════════════════"
log_success "  n8n Installation Complete!"
log_success "═══════════════════════════════════════════"
echo ""

display_connection_info "$APP_NAME" "N8N_USER" "N8N_PASSWORD"
echo ""

log_info "🌐 Access URLs:"
echo "  HTTPS: https://$N8N_DOMAIN"
echo "  Local: http://localhost:5678"
echo ""

log_info "💾 Database:"
echo "  Type: PostgreSQL"
echo "  Database: $N8N_DB_NAME"
echo "  User: $N8N_DB_USER"
echo "  Host: postgres (Docker network)"
echo "  ✅ Production-ready persistent storage"
echo ""

log_info "🔐 SSL Certificate:"
echo "  Domain: $N8N_DOMAIN"
echo "  Email: $N8N_EMAIL"
echo "  Auto-renewal: Enabled (certbot)"
echo ""

log_info "🔑 Security:"
echo "  • HTTPS enabled with Let's Encrypt"
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

log_info "🔧 Nginx management:"
echo "  Test config:  nginx -t"
echo "  Reload:       systemctl reload nginx"
echo "  View logs:    tail -f /var/log/nginx/n8n_access.log"
echo "  Site config:  /etc/nginx/sites-available/$APP_NAME.conf"
echo ""

log_info "🔄 Workflow examples:"
echo "  • Schedule tasks (cron-based triggers)"
echo "  • Webhook automation (HTTPS webhooks)"
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

log_info "💡 Next steps:"
echo "  1. Access https://$N8N_DOMAIN"
echo "  2. Login with generated credentials"
echo "  3. Create your first workflow"
echo "  4. Test with simple HTTP request node"
echo "  5. Configure webhooks (HTTPS enabled)"
echo "  6. Explore workflow templates"
echo ""

log_info "📚 Documentation:"
echo "  • Official docs: https://docs.n8n.io"
echo "  • Workflow templates: https://n8n.io/workflows"
echo "  • Community: https://community.n8n.io"
echo ""

read -p "Press Enter to continue..."

