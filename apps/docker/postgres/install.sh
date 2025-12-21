#!/bin/bash

# Import Library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve utils.sh location (it is now in ../../../lib/utils.sh relative to apps/docker/postgres/install.sh)
if [ -f "$SCRIPT_DIR/../../../lib/utils.sh" ]; then
    source "$SCRIPT_DIR/../../../lib/utils.sh"
elif [ -f "/tmp/lib/utils.sh" ]; then
    source "/tmp/lib/utils.sh"
else
    echo "Error: utils.sh not found."
    exit 1
fi

log_info ">>> STARTING POSTGRESQL INSTALLATION (DOCKER) <<<"

# --- DEPENDENCY CHECK ---
require_dependency "docker/engine"

# --- CREDENTIALS ---
manage_credentials "postgresql" "DB_PASSWORD"
source "$HOME/.vps-secrets/.env_postgresql"

# --- NETWORK ---
if ! docker network inspect vps_network >/dev/null 2>&1; then
    log_info "Creating Docker network 'vps_network'..."
    run_sudo docker network create vps_network
fi

# --- DIRECTORIES ---
BASE_DIR="/opt/database/postgresql"
log_info "Preparing directories at $BASE_DIR..."
run_sudo mkdir -p "$BASE_DIR/data"

# --- DEPLOYMENT ---
CONTAINER_NAME="postgresql-server"

if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
    log_info "Removing existing container..."
    run_sudo docker rm -f $CONTAINER_NAME
fi

log_info "Deploying PostgreSQL Container..."
run_sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -v "$BASE_DIR/data":/var/lib/postgresql/data \
    -p 5432:5432 \
    postgres:latest

log_success "PostgreSQL deployed successfully in Docker!"
