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

log_info ">>> STARTING MARIADB INSTALLATION (DOCKER) <<<"

require_docker

# --- CREDENTIALS ---
manage_credentials "mariadb" "MARIADB_ROOT_PASSWORD"
source "$HOME/.vps-secrets/.env_mariadb"

# --- NETWORK ---
# Create a shared network if it doesn't exist
if ! docker network inspect vps_network >/dev/null 2>&1; then
    log_info "Creating Docker network 'vps_network'..."
    run_sudo docker network create vps_network
fi

# --- DIRECTORIES ---
BASE_DIR="/opt/database/mariadb"
log_info "Preparing directories at $BASE_DIR..."
run_sudo mkdir -p "$BASE_DIR/data"
run_sudo mkdir -p "$BASE_DIR/config"

# --- DEPLOYMENT ---
CONTAINER_NAME="mariadb-server"

if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
    log_info "Removing existing container..."
    run_sudo docker rm -f $CONTAINER_NAME
fi

log_info "Deploying MariaDB Container..."
run_sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    -e MYSQL_ROOT_PASSWORD="$MARIADB_ROOT_PASSWORD" \
    -v "$BASE_DIR/data":/var/lib/mysql \
    -p 3306:3306 \
    mariadb:latest

log_success "MariaDB deployed successfully in Docker!"
