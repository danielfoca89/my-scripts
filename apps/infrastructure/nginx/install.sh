#!/bin/bash

# ==============================================================================
# NGINX REVERSE PROXY INSTALLATION
# Deploys Nginx in Docker container for reverse proxy and web serving
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APP_NAME="nginx"
CONTAINER_NAME="nginx"
DATA_DIR="/opt/infrastructure/nginx"

log_info "═══════════════════════════════════════════"
log_info "  Installing Nginx Reverse Proxy"
log_info "═══════════════════════════════════════════"
echo ""

# Check dependency
log_step "Step 1: Checking dependencies"
if ! check_docker; then
    log_error "Docker is not installed"
    log_info "Please install Docker first: Infrastructure > Docker Engine"
    exit 1
fi
log_success "Docker is available"
echo ""

# Check if already installed
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warn "Nginx container already exists"
    
    if confirm_action "Do you want to reinstall Nginx?"; then
        log_info "Stopping and removing existing container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    else
        log_info "Installation cancelled"
        exit 0
    fi
fi

# Setup directories
log_step "Step 2: Setting up directories"
create_app_directory "$DATA_DIR/conf.d"
create_app_directory "$DATA_DIR/ssl"
create_app_directory "$DATA_DIR/html"
create_app_directory "$DATA_DIR/logs"
log_success "Data directories created: $DATA_DIR"
echo ""

# Create default configuration
log_step "Step 3: Creating default configuration"
cat > "$DATA_DIR/conf.d/default.conf" <<'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create default index page
cat > "$DATA_DIR/html/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; }
        h1 { color: #009639; }
    </style>
</head>
<body>
    <h1>Welcome to Nginx</h1>
    <p>This server is successfully running!</p>
</body>
</html>
EOF

log_success "Configuration files created"
echo ""

# Create Docker network
log_step "Step 4: Setting up Docker network"
create_docker_network "vps_network"
echo ""

# Deploy container
log_step "Step 5: Deploying Nginx container"
log_info "Starting Nginx (alpine)..."

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    -v "${DATA_DIR}/conf.d:/etc/nginx/conf.d:ro" \
    -v "${DATA_DIR}/html:/usr/share/nginx/html:ro" \
    -v "${DATA_DIR}/ssl:/etc/nginx/ssl:ro" \
    -v "${DATA_DIR}/logs:/var/log/nginx" \
    -p 80:80 \
    -p 443:443 \
    --health-cmd="wget --no-verbose --tries=1 --spider http://localhost/health || exit 1" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    nginx:alpine

log_success "Nginx container started"
echo ""

# Wait for Nginx to be ready
log_step "Step 6: Waiting for Nginx to be ready"
log_info "This may take 10-20 seconds..."

if check_container_health "$CONTAINER_NAME" 30; then
    log_success "Nginx is ready!"
else
    log_warn "Health check inconclusive, but container is running"
fi
echo ""

# Verify container health
log_step "Step 7: Verifying installation"
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_success "Nginx is running and healthy"
else
    log_error "Nginx container is not running"
    exit 1
fi
echo ""

# Display connection info
log_success "═══════════════════════════════════════════"
log_success "  Nginx Installation Complete!"
log_success "═══════════════════════════════════════════"
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')

log_info "Access Information:"
echo "  HTTP:  http://${SERVER_IP}"
echo "  HTTPS: https://${SERVER_IP} (configure SSL first)"
echo ""

log_info "Configuration:"
echo "  Config Dir:  $DATA_DIR/conf.d/"
echo "  HTML Dir:    $DATA_DIR/html/"
echo "  SSL Dir:     $DATA_DIR/ssl/"
echo "  Logs Dir:    $DATA_DIR/logs/"
echo ""

log_info "Reverse Proxy Example:"
echo "  # Add to $DATA_DIR/conf.d/app.conf:"
echo "  server {"
echo "      listen 80;"
echo "      server_name app.example.com;"
echo "      location / {"
echo "          proxy_pass http://app_container:8080;"
echo "          proxy_set_header Host \$host;"
echo "          proxy_set_header X-Real-IP \$remote_addr;"
echo "      }"
echo "  }"
echo ""

log_info "Useful commands:"
echo "  docker logs nginx               # View logs"
echo "  docker exec nginx nginx -t      # Test config"
echo "  docker exec nginx nginx -s reload  # Reload config"
echo "  docker restart nginx            # Restart container"
echo ""

log_warn "Security Note:"
echo "  • Configure SSL certificates for HTTPS (use Certbot)"
echo "  • Update firewall rules to allow ports 80 and 443"
echo "  • Add custom configurations in $DATA_DIR/conf.d/"
echo ""

read -p "Press Enter to continue..."
