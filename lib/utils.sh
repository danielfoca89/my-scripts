#!/bin/bash

# ==============================================================================
# SHARED UTILITIES LIBRARY
# This file contains common functions for logging, sudo handling, OS detection,
# and firewall management. It is imported by all installation scripts.
# ==============================================================================

# --- 1. COLORS FOR LOGGING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- 2. LOGGING FUNCTIONS ---
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}>>> $1${NC}"
}

# --- 3. SUDO WRAPPER (CRITICAL SECURITY) ---
# Executes commands with root privileges.
# Priority:
# 1. SUDO_PASS env var (CI/CD)
# 2. Current user is root (No sudo needed)
# 3. Passwordless sudo (Local dev)
run_sudo() {
    # If we are root, run directly
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
        return $?
    fi

    # If SUDO_PASS is provided (GitHub Actions / Automation)
    if [ -n "$SUDO_PASS" ]; then
        echo "$SUDO_PASS" | sudo -S -p "" "$@" 2>/dev/null
        return $?
    fi

    # Try passwordless sudo or interactive sudo (Local execution)
    if sudo -n true 2>/dev/null; then
        sudo "$@"
    else
        # If interactive, let sudo prompt. If non-interactive, this will fail.
        if [ -t 0 ]; then
            sudo "$@"
        else
            log_error "Root privileges required. Please set SUDO_PASS or run as root."
            exit 1
        fi
    fi
}
# --- 4. CREDENTIAL MANAGEMENT ---
# Manages .env files in a secure hidden directory.
# Usage: manage_credentials "app_name" "VAR_NAME"
# Example: manage_credentials "postgresql" "DB_PASSWORD"
manage_credentials() {
    local app_name=$1
    local var_name=$2
    local secrets_dir="$HOME/.vps-secrets"
    local env_file="$secrets_dir/.env_${app_name}"

    # Create secrets directory if it doesn't exist
    if [ ! -d "$secrets_dir" ]; then
        mkdir -p "$secrets_dir"
        chmod 700 "$secrets_dir"
        log_info "Created secrets directory: $secrets_dir"
    fi

    # Check if env file exists
    if [ -f "$env_file" ]; then
        log_info "Loading existing credentials from $env_file"
        source "$env_file"
    else
        log_info "Generating new credentials for $app_name..."
        
        # Generate a strong random password (alphanumeric)
        local generated_pass=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9')
        
        # Save to file
        echo "${var_name}='${generated_pass}'" > "$env_file"
        chmod 600 "$env_file"
        
        log_info "Credentials saved to $env_file"
        
        # Export immediately for current session
        export "${var_name}=${generated_pass}"
    fi
}
# --- 4. OS DETECTION ---
# Sets global variables: OS_NAME, OS_VERSION, PACKAGE_MANAGER, PARENT_OS, PARENT_CODENAME
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        
        # Handle Derivatives (Mint, Pop, Kali -> Ubuntu/Debian)
        if [ -n "$UBUNTU_CODENAME" ]; then
            PARENT_OS="ubuntu"
            PARENT_CODENAME="$UBUNTU_CODENAME"
        elif [[ "$ID_LIKE" == *"ubuntu"* ]]; then
            PARENT_OS="ubuntu"
            PARENT_CODENAME="${VERSION_CODENAME:-noble}" # Fallback to recent LTS
        elif [[ "$ID_LIKE" == *"debian"* ]]; then
            PARENT_OS="debian"
            PARENT_CODENAME="${VERSION_CODENAME:-bookworm}"
        else
            PARENT_OS="$ID"
            PARENT_CODENAME="$VERSION_CODENAME"
        fi
    else
        log_error "Cannot detect OS. /etc/os-release file is missing."
        exit 1
    fi

    case "$OS_NAME" in
        ubuntu|debian|pop|linuxmint|kali)
            PACKAGE_MANAGER="apt"
            ;;
        centos|rhel|fedora|almalinux|rocky|ol)
            PACKAGE_MANAGER="yum"
            ;;
        *)
            if [[ "$ID_LIKE" == *"debian"* ]]; then
                PACKAGE_MANAGER="apt"
            elif [[ "$ID_LIKE" == *"rhel"* ]] || [[ "$ID_LIKE" == *"fedora"* ]]; then
                PACKAGE_MANAGER="yum"
            else
                log_warn "Unknown OS ($OS_NAME). Defaulting to 'apt', but script might fail."
                PACKAGE_MANAGER="apt"
            fi
            ;;
    esac

    log_info "System: $NAME ($VERSION_ID) | Base: ${PARENT_OS:-$OS_NAME} | Manager: $PACKAGE_MANAGER"
}

# --- 5. FIREWALL MANAGER (SMART) ---
# Automatically detects UFW (Ubuntu) or Firewalld (CentOS) and opens ports.
open_port() {
    local PORT=$1
    local COMMENT=$2
    local PROTO=${3:-tcp}

    if [ -z "$PORT" ]; then
        log_error "open_port function called without port number."
        return 1
    fi

    log_info "Configuring Firewall for: $COMMENT (Port $PORT/$PROTO)"

    # Check for UFW (Ubuntu Standard)
    if command -v ufw >/dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            run_sudo ufw allow "$PORT/$PROTO" comment "$COMMENT"
            run_sudo ufw reload >/dev/null
            log_info "Rule added to UFW."
        else
            log_warn "UFW is installed but inactive. Port not explicitly opened."
        fi

    # Check for Firewalld (CentOS/RHEL Standard)
    elif command -v firewall-cmd >/dev/null; then
        if systemctl is-active --quiet firewalld; then
            run_sudo firewall-cmd --permanent --add-port="$PORT/$PROTO" >/dev/null
            run_sudo firewall-cmd --reload >/dev/null
            log_info "Rule added to Firewalld."
        else
            log_warn "Firewalld is installed but inactive."
        fi
    else
        log_warn "No supported firewall (UFW/Firewalld) detected. Ensure port $PORT is accessible."
    fi
}

# --- 6. DOCKER CHECKER ---
# Helper to ensure Docker is running before installing container apps
require_docker() {
    if ! command -v docker >/dev/null; then
        log_error "Docker is NOT installed. Please run the Docker installation script first."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        # Try with sudo if current user can't access docker socket
        if ! run_sudo docker info >/dev/null 2>&1; then
             log_error "Docker is installed but not running or accessible."
             exit 1
        fi
    fi
}

# --- 7. NGINX PROXY SETUP ---
setup_nginx_proxy() {
    local DOMAIN=$1
    local PORT=$2
    local EMAIL=$3
    local CONTAINER_NAME=$4 # Optional: If provided, we try to get the container IP

    log_info "Configuring Nginx Reverse Proxy for $DOMAIN..."

    # Determine Upstream Target
    local UPSTREAM_TARGET="127.0.0.1:$PORT"
    
    if [ -n "$CONTAINER_NAME" ]; then
        # Try to get Docker Container IP
        if command -v docker &> /dev/null; then
            local CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)
            if [ -n "$CONTAINER_IP" ]; then
                log_info "Detected Docker Container IP for $CONTAINER_NAME: $CONTAINER_IP"
                UPSTREAM_TARGET="$CONTAINER_IP:$PORT"
            else
                log_warn "Could not detect IP for container '$CONTAINER_NAME'. Falling back to 127.0.0.1"
            fi
        fi
    fi

    log_info "Upstream set to: $UPSTREAM_TARGET"

    # Check if Nginx is installed
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx is not installed. Please run apps/web/nginx.sh first."
        return 1
    fi

    # Check if Certbot is installed
    if ! command -v certbot &> /dev/null; then
        log_warn "Certbot is not installed. Attempting to install..."
        if [ -f "$SCRIPT_DIR/../../apps/web/certbot.sh" ]; then
            bash "$SCRIPT_DIR/../../apps/web/certbot.sh"
        elif [ -f "/tmp/apps/web/certbot.sh" ]; then
            bash "/tmp/apps/web/certbot.sh"
        else
            log_error "Certbot installation script not found. Please install Certbot manually."
            return 1
        fi
        
        # Re-check
        if ! command -v certbot &> /dev/null; then
             log_error "Certbot installation failed."
             return 1
        fi
    fi

    # Locate Template
    local TEMPLATE_PATH=""
    if [ -f "$SCRIPT_DIR/../../lib/config/nginx/proxy_template.conf" ]; then
        TEMPLATE_PATH="$SCRIPT_DIR/../../lib/config/nginx/proxy_template.conf"
    elif [ -f "/tmp/lib/config/nginx/proxy_template.conf" ]; then
        TEMPLATE_PATH="/tmp/lib/config/nginx/proxy_template.conf"
    else
        log_error "Nginx proxy template not found!"
        return 1
    fi

    # Create Config
    local CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"
    
    # Read template and replace variables
    # We use sed to replace {{DOMAIN}} and {{UPSTREAM}}
    local TEMP_CONFIG=$(mktemp)
    
    # Construct Upstream (IP:PORT)
    # If UPSTREAM_TARGET is already set (either 127.0.0.1:PORT or CONTAINER_IP:PORT)
    # We just use it directly.
    
    sed -e "s/{{DOMAIN}}/$DOMAIN/g" \
        -e "s/{{UPSTREAM}}/$UPSTREAM_TARGET/g" \
        "$TEMPLATE_PATH" > "$TEMP_CONFIG"

    log_info "Installing Nginx configuration to $CONFIG_FILE..."
    run_sudo mv "$TEMP_CONFIG" "$CONFIG_FILE"
    
    # Enable Site
    if [ ! -L "/etc/nginx/sites-enabled/$DOMAIN" ]; then
        run_sudo ln -s "$CONFIG_FILE" "/etc/nginx/sites-enabled/$DOMAIN"
    fi

    # Test Configuration
    if run_sudo nginx -t; then
        run_sudo systemctl reload nginx
        log_info "Nginx configuration reloaded."
    else
        log_error "Nginx configuration test failed! Reverting..."
        run_sudo rm "/etc/nginx/sites-enabled/$DOMAIN"
        return 1
    fi

    # Obtain SSL Certificate
    log_info "Obtaining SSL Certificate for $DOMAIN..."
    if run_sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect; then
        log_info "SSL Certificate installed successfully!"
        log_info "Your application is accessible at: https://$DOMAIN"
    else
        log_error "Certbot failed to obtain certificate. Please check your domain DNS settings."
        log_warn "The site is available via HTTP at http://$DOMAIN"
    fi
}

