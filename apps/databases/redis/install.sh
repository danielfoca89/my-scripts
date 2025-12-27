#!/bin/bash

# ==============================================================================
# REDIS CACHE/DATABASE INSTALLATION
# Deploys Redis in Docker container with auto-generated password
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APP_NAME="redis"
CONTAINER_NAME="redis"
DATA_DIR="/opt/databases/redis"

log_info "═══════════════════════════════════════════"
log_info "  Installing Redis Cache/Database"
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
    log_warn "Redis container already exists"
    
    if has_credentials "$APP_NAME"; then
        log_info "Using existing credentials from ~/.vps-secrets/.env_${APP_NAME}"
        
        if confirm_action "Do you want to reinstall Redis?"; then
            log_info "Stopping and removing existing container..."
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm "$CONTAINER_NAME" 2>/dev/null || true
        else
            log_info "Installation cancelled"
            exit 0
        fi
    fi
fi

# Manage credentials
log_step "Step 2: Managing credentials"
if ! has_credentials "$APP_NAME"; then
    log_info "Generating secure password..."
    
    REDIS_PASSWORD=$(generate_secure_password)
    
    save_secret "$APP_NAME" "REDIS_PASSWORD" "$REDIS_PASSWORD"
    
    log_success "Password generated and saved"
else
    log_info "Loading existing credentials..."
fi

load_secrets "$APP_NAME"
log_success "Credentials loaded"
echo ""

# Setup directories
log_step "Step 3: Setting up directories"
create_app_directory "$DATA_DIR/data"
log_success "Data directory created: $DATA_DIR"
echo ""

# Create Redis configuration
log_step "Step 4: Creating Redis configuration"
cat > "${DATA_DIR}/redis.conf" << EOF
# Redis Configuration
requirepass $REDIS_PASSWORD
bind 0.0.0.0
protected-mode yes
port 6379

# Persistence
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfilename "appendonly.aof"

# Limits
maxmemory 256mb
maxmemory-policy allkeys-lru

# Logging
loglevel notice

# Performance
tcp-backlog 511
timeout 0
tcp-keepalive 300
EOF

log_success "Redis configuration created"
echo ""

# Deploy container
log_step "Step 5: Deploying Redis container"
log_info "Starting Redis 7..."

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    -v "${DATA_DIR}/data:/data" \
    -v "${DATA_DIR}/redis.conf:/usr/local/etc/redis/redis.conf" \
    -p 6379:6379 \
    redis:7-alpine \
    redis-server /usr/local/etc/redis/redis.conf

log_success "Redis container started"
echo ""

# Wait for Redis to be ready
log_step "Step 6: Waiting for Redis to be ready"
log_info "This may take 10-20 seconds..."

MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker exec "$CONTAINER_NAME" redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q "PONG"; then
        log_success "Redis is ready!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 1
    echo -n "."
done
echo ""

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    log_error "Redis did not become ready in time"
    log_info "Check logs: docker logs $CONTAINER_NAME"
    exit 1
fi
echo ""

# Verify container health
log_step "Step 7: Verifying installation"
if check_container_health "$CONTAINER_NAME"; then
    log_success "Redis is running and healthy"
else
    log_warn "Container is running but health check inconclusive"
fi

# Get Redis info
log_info "Redis version:"
docker exec "$CONTAINER_NAME" redis-cli -a "$REDIS_PASSWORD" info server 2>/dev/null | grep "redis_version" || true
echo ""

# Display connection info
log_success "═══════════════════════════════════════════"
log_success "  Redis Installation Complete!"
log_success "═══════════════════════════════════════════"
echo ""

display_connection_info "$APP_NAME"

echo ""
log_info "Connection examples:"
echo "  # From host:"
echo "  redis-cli -h 127.0.0.1 -p 6379 -a '<password>'"
echo ""
echo "  # From another container:"
echo "  redis-cli -h redis -p 6379 -a '<password>'"
echo ""
echo "  # Connection string:"
echo "  redis://:<password>@redis:6379/0"
echo ""

log_info "Useful commands:"
echo "  docker logs redis            # View logs"
echo "  docker exec -it redis redis-cli -a '<password>' # Access Redis CLI"
echo "  docker stop redis            # Stop container"
echo "  docker start redis           # Start container"
echo ""

log_info "Redis CLI examples:"
echo "  PING                         # Test connection"
echo "  SET key value                # Set a key"
echo "  GET key                      # Get a key"
echo "  INFO                         # Server info"
echo "  DBSIZE                       # Number of keys"
echo ""
cat <<'EXAMPLE'
Example Implementation:
-----------------------

# Check dependencies
require_dependency "infrastructure/docker-engine"

# Manage credentials
if ! has_credentials "$APP_NAME"; then
    PASSWORD=$(generate_secure_password)
    save_secret "$APP_NAME" "APP_PASSWORD" "$PASSWORD"
fi
load_secrets "$APP_NAME"

# Deploy
docker run -d \
    --name $APP_NAME \
    --restart unless-stopped \
    --network vps_network \
    -e PASSWORD="$APP_PASSWORD" \
    -p 8080:8080 \
    your-image:latest

# Verify
check_container_health "$APP_NAME"
display_connection_info "$APP_NAME"

EXAMPLE

echo ""
read -p "Press Enter to continue..."
