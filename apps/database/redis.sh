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

log_info ">>> STARTING REDIS INSTALLATION (DOCKER) <<<"

require_docker

# --- CREDENTIALS ---
manage_credentials "redis" "REDIS_PASSWORD"
source "$HOME/.vps-secrets/.env_redis"

# --- NETWORK ---
if ! docker network inspect vps_network >/dev/null 2>&1; then
    log_info "Creating Docker network 'vps_network'..."
    run_sudo docker network create vps_network
fi

# --- DIRECTORIES ---
BASE_DIR="/opt/database/redis"
log_info "Preparing directories at $BASE_DIR..."
run_sudo mkdir -p "$BASE_DIR/data"

# --- DEPLOYMENT ---
CONTAINER_NAME="redis-server"

if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
    log_info "Removing existing container..."
    run_sudo docker rm -f $CONTAINER_NAME
fi

log_info "Deploying Redis Container..."
run_sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    -v "$BASE_DIR/data":/data \
    -p 6379:6379 \
    redis:latest redis-server --requirepass "$REDIS_PASSWORD"

log_success "Redis deployed successfully in Docker!"
