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

log_info ">>> STARTING MONGODB INSTALLATION (DOCKER) <<<"

require_docker

# --- CREDENTIALS ---
manage_credentials "mongodb" "MONGO_ROOT_PASSWORD"
manage_credentials "mongodb" "MONGO_ROOT_USER"
source "$HOME/.vps-secrets/.env_mongodb"

# --- NETWORK ---
if ! docker network inspect vps_network >/dev/null 2>&1; then
    log_info "Creating Docker network 'vps_network'..."
    run_sudo docker network create vps_network
fi

# --- DIRECTORIES ---
BASE_DIR="/opt/database/mongodb"
log_info "Preparing directories at $BASE_DIR..."
run_sudo mkdir -p "$BASE_DIR/data"

# --- DEPLOYMENT ---
CONTAINER_NAME="mongodb-server"

if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
    log_info "Removing existing container..."
    run_sudo docker rm -f $CONTAINER_NAME
fi

log_info "Deploying MongoDB Container..."
run_sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    -e MONGO_INITDB_ROOT_USERNAME="$MONGO_ROOT_USER" \
    -e MONGO_INITDB_ROOT_PASSWORD="$MONGO_ROOT_PASSWORD" \
    -v "$BASE_DIR/data":/data/db \
    -p 27017:27017 \
    mongo:latest

log_success "MongoDB deployed successfully in Docker!"
