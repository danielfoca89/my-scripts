#!/bin/bash

# Import Library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve utils.sh location (it is now in ../../../lib/utils.sh relative to apps/docker/n8n/install.sh)
if [ -f "$SCRIPT_DIR/../../../lib/utils.sh" ]; then
    source "$SCRIPT_DIR/../../../lib/utils.sh"
elif [ -f "/tmp/lib/utils.sh" ]; then
    source "/tmp/lib/utils.sh"
else
    echo "Error: utils.sh not found."
    exit 1
fi

log_info ">>> STARTING N8N AUTOMATION TOOL INSTALLATION (DOCKER) <<<"

# --- ARGUMENT PARSING ---
DOMAIN_NAME=""
SSL_EMAIL=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN_NAME="$2"; shift ;;
        --email) SSL_EMAIL="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# --- DEPENDENCY CHECK ---
# n8n needs Docker and Postgres. We request them here.
require_dependency "docker/engine"
require_dependency "docker/postgres"

# --- DATABASE CONFIGURATION (PostgreSQL) ---
# 1. Check for PostgreSQL Dependency
if [ ! -f "$HOME/.vps-secrets/.env_postgresql" ]; then
    log_error "PostgreSQL credentials not found even after dependency check."
    exit 1
fi

# Load Postgres Root Password
source "$HOME/.vps-secrets/.env_postgresql"

# Manage Credentials
manage_credentials "n8n" "N8N_DB_PASSWORD"

# Generate Random Database Name and User if not set
ENV_FILE="$HOME/.vps-secrets/.env_n8n"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

if [ -z "$N8N_DB_USER" ]; then
    RAND_SUFFIX=$(openssl rand -hex 4)
    N8N_DB_USER="n8n_user_${RAND_SUFFIX}"
    echo "N8N_DB_USER='$N8N_DB_USER'" >> "$ENV_FILE"
    log_info "Generated random DB User: $N8N_DB_USER"
fi

if [ -z "$N8N_DB_NAME" ]; then
    RAND_SUFFIX=$(openssl rand -hex 4)
    N8N_DB_NAME="n8n_db_${RAND_SUFFIX}"
    echo "N8N_DB_NAME='$N8N_DB_NAME'" >> "$ENV_FILE"
    log_info "Generated random DB Name: $N8N_DB_NAME"
fi

# Configure Database (via Docker Exec)
log_info "Configuring PostgreSQL for n8n..."

# Wait for Postgres container
if ! docker ps | grep -q postgresql-server; then
    log_error "PostgreSQL container 'postgresql-server' is not running."
    exit 1
fi

# Create User
run_sudo docker exec postgresql-server psql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname = '$N8N_DB_USER'" | grep -q 1 ||     run_sudo docker exec postgresql-server psql -U postgres -c "CREATE USER \"$N8N_DB_USER\" WITH ENCRYPTED PASSWORD '$N8N_DB_PASSWORD';"

# Create DB
run_sudo docker exec postgresql-server psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$N8N_DB_NAME'" | grep -q 1 ||     run_sudo docker exec postgresql-server psql -U postgres -c "CREATE DATABASE \"$N8N_DB_NAME\" OWNER \"$N8N_DB_USER\";"

run_sudo docker exec postgresql-server psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$N8N_DB_NAME\" TO \"$N8N_DB_USER\";"

log_info "Database '$N8N_DB_NAME' configured for user '$N8N_DB_USER'."

# Set Docker Env Vars for Postgres
DB_ENV_VARS="-e DB_TYPE=postgresdb \
-e DB_POSTGRESDB_DATABASE=$N8N_DB_NAME \
-e DB_POSTGRESDB_HOST=postgresql-server \
-e DB_POSTGRESDB_PORT=5432 \
-e DB_POSTGRESDB_USER=$N8N_DB_USER \
-e DB_POSTGRESDB_PASSWORD=$N8N_DB_PASSWORD"

# 2. Manage General Credentials
manage_credentials "n8n" "N8N_ENCRYPTION_KEY"
manage_credentials "n8n" "N8N_BASIC_AUTH_USER"
manage_credentials "n8n" "N8N_BASIC_AUTH_PASSWORD"

# 4. Prepare Docker Environment
DATA_DIR="$HOME/.n8n-data"
mkdir -p "$DATA_DIR"

# Ensure Network
if ! docker network inspect vps_network >/dev/null 2>&1; then
    run_sudo docker network create vps_network
fi

# --- NGINX PROXY CONFIGURATION (PRE-DEPLOYMENT) ---
PROXY_ENV_VARS=""

# If arguments were not passed, ask interactively
if [ -z "$DOMAIN_NAME" ]; then
    echo ""
    log_info "Would you like to configure a Domain and SSL for n8n? (y/n)"
    read -r CONFIGURE_DOMAIN

    if [[ "$CONFIGURE_DOMAIN" =~ ^[Yy]$ ]]; then
        echo -n "Enter your domain (e.g., n8n.example.com): "
        read -r DOMAIN_NAME
        
        echo -n "Enter your email for SSL renewal (e.g., admin@example.com): "
        read -r SSL_EMAIL
    fi
fi

if [ -n "$DOMAIN_NAME" ] && [ -n "$SSL_EMAIL" ]; then
    # Set Environment Variables required for Reverse Proxy
    # See: https://docs.n8n.io/hosting/configuration/configuration-examples/webhook-url/
    PROXY_ENV_VARS="-e WEBHOOK_URL=https://$DOMAIN_NAME \
    -e N8N_EDITOR_BASE_URL=https://$DOMAIN_NAME \
    -e N8N_PROTOCOL=https \
    -e N8N_HOST=$DOMAIN_NAME \
    -e N8N_PORT=5678 \
    -e N8N_PROXY_HOPS=1"
    
    log_info "Configuring n8n for domain: $DOMAIN_NAME"
else
    log_warn "Domain or Email not provided. Skipping Nginx configuration."
fi

log_info "Deploying n8n Container..."

run_sudo docker rm -f n8n >/dev/null 2>&1 || true

# We use eval to properly expand the variable strings
eval "run_sudo docker run -d \
    --name n8n \
    --network vps_network \
    --restart unless-stopped \
    $DB_ENV_VARS \
    $PROXY_ENV_VARS \
    -e N8N_ENCRYPTION_KEY='$N8N_ENCRYPTION_KEY' \
    -e N8N_BASIC_AUTH_ACTIVE=true \
    -e N8N_BASIC_AUTH_USER='$N8N_BASIC_AUTH_USER' \
    -e N8N_BASIC_AUTH_PASSWORD='$N8N_BASIC_AUTH_PASSWORD' \
    -v '$DATA_DIR':/home/node/.n8n \
    -p 5678:5678 \
    docker.n8n.io/n8nio/n8n"

# 5. Firewall
open_port 5678 "n8n Workflow Automation"

log_info "n8n installed successfully."

if [ -n "$DOMAIN_NAME" ]; then
    # Run the Nginx Setup with Container Name for IP detection
    setup_nginx_proxy "$DOMAIN_NAME" "5678" "$SSL_EMAIL" "n8n"
else
    log_info "   - URL: http://YOUR_IP:5678"
fi

log_info "   - Database: Connected to Dockerized PostgreSQL"

