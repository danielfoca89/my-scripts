#!/bin/bash

# ==============================================================================
# CERTBOT SSL CERTIFICATE MANAGEMENT
# Manages Let's Encrypt SSL certificates for domains with automatic renewal
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APP_NAME="certbot"
DATA_DIR="/opt/infrastructure/certbot"

log_info "═══════════════════════════════════════════"
log_info "  Installing Certbot (Let's Encrypt)"
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

# Check if Nginx is running
NGINX_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q "^nginx$"; then
    NGINX_RUNNING=true
    log_success "Nginx detected - webroot mode available"
else
    log_warn "Nginx not detected - standalone mode will be used"
    log_info "Standalone mode requires port 80 to be free during certificate requests"
fi
echo ""

# Setup directories
log_step "Step 2: Setting up directories"
create_app_directory "$DATA_DIR/conf"
create_app_directory "$DATA_DIR/www"
create_app_directory "$DATA_DIR/logs"
create_app_directory "/var/www/certbot"
log_success "Certbot directories created"
echo ""

# Create helper scripts
log_step "Step 3: Creating helper scripts"

# Certificate request script
cat > "$DATA_DIR/request-cert.sh" << 'EOFSCRIPT'
#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo -e "${RED}Usage:${NC} $0 <domain> <email> [additional-domains...]"
    echo ""
    echo "Examples:"
    echo "  $0 example.com admin@example.com"
    echo "  $0 example.com admin@example.com www.example.com api.example.com"
    exit 1
fi

DOMAIN="$1"
EMAIL="$2"
shift 2
ADDITIONAL_DOMAINS="$@"

# Build domain arguments
DOMAIN_ARGS="-d $DOMAIN"
for extra in $ADDITIONAL_DOMAINS; do
    DOMAIN_ARGS="$DOMAIN_ARGS -d $extra"
done

echo -e "${GREEN}Requesting certificate for:${NC} $DOMAIN"
[ -n "$ADDITIONAL_DOMAINS" ] && echo -e "${GREEN}Additional domains:${NC} $ADDITIONAL_DOMAINS"
echo ""

# Check if certificate already exists
if [ -d "/opt/infrastructure/certbot/conf/live/$DOMAIN" ]; then
    echo -e "${YELLOW}Warning:${NC} Certificate for $DOMAIN already exists"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Check if Nginx is running
if docker ps --format '{{.Names}}' | grep -q "^nginx$"; then
    echo -e "${GREEN}Using webroot mode${NC} (Nginx integration)"
    
    # Ensure Nginx serves the .well-known directory
    docker exec nginx test -d /var/www/certbot/.well-known || \
        docker exec nginx mkdir -p /var/www/certbot/.well-known
    
    docker run --rm --name certbot \
        -v "/opt/infrastructure/certbot/conf:/etc/letsencrypt" \
        -v "/opt/infrastructure/certbot/www:/var/www/certbot" \
        -v "/opt/infrastructure/certbot/logs:/var/log/letsencrypt" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        $DOMAIN_ARGS
else
    echo -e "${YELLOW}Using standalone mode${NC} (port 80 required)"
    echo "Warning: This will temporarily use port 80"
    
    docker run --rm --name certbot \
        -v "/opt/infrastructure/certbot/conf:/etc/letsencrypt" \
        -v "/opt/infrastructure/certbot/logs:/var/log/letsencrypt" \
        -p 80:80 \
        certbot/certbot certonly \
        --standalone \
        --preferred-challenges http \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        $DOMAIN_ARGS
fi

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Certificate obtained successfully!${NC}"
    echo ""
    echo "Certificate files:"
    echo "  Location: /opt/infrastructure/certbot/conf/live/$DOMAIN/"
    echo "  Fullchain: fullchain.pem"
    echo "  Private key: privkey.pem"
    echo ""
    echo "Nginx configuration example:"
    echo "  ssl_certificate /etc/nginx/ssl/live/$DOMAIN/fullchain.pem;"
    echo "  ssl_certificate_key /etc/nginx/ssl/live/$DOMAIN/privkey.pem;"
    echo ""
    echo "Don't forget to:"
    echo "  1. Update your Nginx configuration"
    echo "  2. Reload Nginx: docker exec nginx nginx -s reload"
else
    echo ""
    echo -e "${RED}❌ Certificate request failed${NC}"
    echo "Check logs: /opt/infrastructure/certbot/logs/"
    exit 1
fi
EOFSCRIPT

chmod +x "$DATA_DIR/request-cert.sh"

# Certificate renewal script
cat > "$DATA_DIR/renew-certs.sh" << 'EOFSCRIPT'
#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🔄 Renewing all certificates..."
echo ""

docker run --rm --name certbot \
    -v "/opt/infrastructure/certbot/conf:/etc/letsencrypt" \
    -v "/opt/infrastructure/certbot/www:/var/www/certbot" \
    -v "/opt/infrastructure/certbot/logs:/var/log/letsencrypt" \
    certbot/certbot renew \
    --webroot \
    --webroot-path=/var/www/certbot

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Certificate renewal complete${NC}"
    
    # Reload Nginx if running
    if docker ps --format '{{.Names}}' | grep -q "^nginx$"; then
        echo "Reloading Nginx..."
        docker exec nginx nginx -s reload
        echo -e "${GREEN}✅ Nginx reloaded${NC}"
    fi
else
    echo ""
    echo -e "${RED}❌ Certificate renewal failed${NC}"
    exit 1
fi
EOFSCRIPT

chmod +x "$DATA_DIR/renew-certs.sh"

# List certificates script
cat > "$DATA_DIR/list-certs.sh" << 'EOFSCRIPT'
#!/bin/bash

echo "📜 Installed SSL Certificates:"
echo ""

docker run --rm \
    -v "/opt/infrastructure/certbot/conf:/etc/letsencrypt" \
    certbot/certbot certificates
EOFSCRIPT

chmod +x "$DATA_DIR/list-certs.sh"

# Revoke certificate script
cat > "$DATA_DIR/revoke-cert.sh" << 'EOFSCRIPT'
#!/bin/bash
set -euo pipefail

if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN="$1"

if [ ! -d "/opt/infrastructure/certbot/conf/live/$DOMAIN" ]; then
    echo "Error: No certificate found for $DOMAIN"
    exit 1
fi

echo "⚠️  Warning: This will revoke the certificate for $DOMAIN"
read -p "Continue? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

docker run --rm \
    -v "/opt/infrastructure/certbot/conf:/etc/letsencrypt" \
    certbot/certbot revoke \
    --cert-name "$DOMAIN" \
    --delete-after-revoke

echo "✅ Certificate revoked"
EOFSCRIPT

chmod +x "$DATA_DIR/revoke-cert.sh"

log_success "Helper scripts created"
echo ""

# Setup automatic renewal
log_step "Step 4: Setting up automatic renewal"

# Check for systemd
if command -v systemctl &> /dev/null; then
    log_info "Creating systemd timer for automatic renewal..."
    
    sudo tee /etc/systemd/system/certbot-renewal.service > /dev/null << 'EOFSERVICE'
[Unit]
Description=Certbot Certificate Renewal
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/opt/infrastructure/certbot/renew-certs.sh
StandardOutput=journal
StandardError=journal
EOFSERVICE

    sudo tee /etc/systemd/system/certbot-renewal.timer > /dev/null << 'EOFTIMER'
[Unit]
Description=Run Certbot renewal twice daily
Requires=certbot-renewal.service

[Timer]
OnCalendar=*-*-* 03:00:00
OnCalendar=*-*-* 15:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOFTIMER

    sudo systemctl daemon-reload
    sudo systemctl enable certbot-renewal.timer
    sudo systemctl start certbot-renewal.timer
    
    log_success "Systemd timer configured (runs at 3 AM and 3 PM daily)"
else
    log_info "Setting up cron job for automatic renewal..."
    
    # Add cron job if not exists
    CRON_CMD="0 3,15 * * * /opt/infrastructure/certbot/renew-certs.sh >> /var/log/certbot-renewal.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "renew-certs.sh"; echo "$CRON_CMD") | crontab -
    
    log_success "Cron job configured (runs at 3 AM and 3 PM daily)"
fi
echo ""

# Pull Certbot image
log_step "Step 5: Pulling Certbot Docker image"
docker pull certbot/certbot:latest
log_success "Certbot image ready"
echo ""

# Display info
log_success "═══════════════════════════════════════════"
log_success "  Certbot Installation Complete!"
log_success "═══════════════════════════════════════════"
echo ""

log_info "📁 Certbot directories:"
echo "  Certificates: $DATA_DIR/conf/live/"
echo "  Webroot: $DATA_DIR/www/"
echo "  Logs: $DATA_DIR/logs/"
echo ""

log_info "🔧 Helper scripts:"
echo "  Request certificate:  sudo $DATA_DIR/request-cert.sh <domain> <email>"
echo "  Renew certificates:   sudo $DATA_DIR/renew-certs.sh"
echo "  List certificates:    sudo $DATA_DIR/list-certs.sh"
echo "  Revoke certificate:   sudo $DATA_DIR/revoke-cert.sh <domain>"
echo ""

log_info "📝 Usage examples:"
echo "  # Request certificate for single domain:"
echo "  sudo $DATA_DIR/request-cert.sh example.com admin@example.com"
echo ""
echo "  # Request certificate with www subdomain:"
echo "  sudo $DATA_DIR/request-cert.sh example.com admin@example.com www.example.com"
echo ""
echo "  # Request wildcard certificate (requires DNS validation):"
echo "  sudo $DATA_DIR/request-cert.sh '*.example.com' admin@example.com"
echo ""

log_info "🔄 Automatic renewal:"
echo "  • Certificates renew automatically twice daily (3 AM & 3 PM)"
echo "  • Renewal starts 30 days before expiration"
echo "  • Nginx reloads automatically after renewal"
echo ""

if [ "$NGINX_RUNNING" = true ]; then
    log_info "🔗 Nginx integration:"
    echo "  ✅ Nginx is running - webroot validation ready"
    echo "  • Certificates location: $DATA_DIR/conf/live/DOMAIN/"
    echo "  • Mount in Nginx: -v $DATA_DIR/conf:/etc/nginx/ssl:ro"
    echo "  • Mount webroot: -v $DATA_DIR/www:/var/www/certbot:ro"
else
    log_warn "🔗 Nginx not detected:"
    echo "  • Standalone mode will use port 80 during requests"
    echo "  • Consider installing Nginx for easier management"
    echo "  • Port 80 must be available during certificate requests"
fi
echo ""

log_warn "⚠️  Important notes:"
echo "  • Certificates expire after 90 days"
echo "  • Rate limits: 50 certificates per domain per week"
echo "  • 5 duplicate certificates per week"
echo "  • Ensure DNS points to this server before requesting"
echo "  • Port 80 must be accessible from internet"
echo ""

log_info "💡 Next steps:"
echo "  1. Verify DNS points to: $(hostname -I | awk '{print $1}')"
echo "  2. Ensure firewall allows port 80 (HTTP)"
echo "  3. Request your first certificate"
echo "  4. Configure Nginx to use the certificate"
echo "  5. Test renewal: sudo $DATA_DIR/renew-certs.sh --dry-run"
echo ""
