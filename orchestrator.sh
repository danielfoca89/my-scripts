#!/bin/bash

# VPS Orchestrator - Automatic dependency management
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APPS_CONF="${SCRIPT_DIR}/config/apps.conf"

# Function to read app config from apps.conf
get_app_config() {
    local app_name="$1"
    local key="$2"
    
    # Read value from apps.conf
    awk -v app="$app_name" -v key="$key" '
        /^\[/ { section=$0; gsub(/[\[\]]/, "", section) }
        section == app && $0 ~ "^"key"=" { 
            split($0, a, "="); 
            gsub(/^[ \t]+|[ \t]+$/, "", a[2]);
            print a[2];
            exit
        }
    ' "$APPS_CONF"
}

# Function to check if an app is installed AND running
is_app_installed() {
    local app_name="$1"
    
    case "$app_name" in
        docker-engine)
            if command -v docker &>/dev/null; then
                if systemctl is-active --quiet docker 2>/dev/null; then
                     return 0
                else
                     # Docker is installed but not active - start it
                     if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
                         sudo systemctl start docker &>/dev/null || true
                         sleep 2
                         systemctl is-active --quiet docker 2>/dev/null && return 0
                     fi
                     return 1
                fi
            else
                return 1
            fi
            ;;
        nginx)
            if command -v nginx &>/dev/null; then
                systemctl is-active --quiet nginx 2>/dev/null && return 0
                
                # Try to start
                if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
                     sudo systemctl start nginx &>/dev/null || true
                     sleep 1
                     systemctl is-active --quiet nginx 2>/dev/null && return 0
                fi
                return 1
            else
                return 1
            fi
            ;;
        postgres)
            if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
                # Check if container exists first (stopped or running)
                if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^postgres$"; then
                    # Container exists, is it running?
                    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^postgres$"; then
                        return 0
                    else
                        # Container exists but stopped - try start
                        docker start postgres &>/dev/null || true
                        sleep 2
                        docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^postgres$" && return 0
                        return 1
                    fi
                else
                    return 1
                fi
            else
                return 1
            fi
            ;;
        redis)
            if systemctl is-active --quiet redis-server 2>/dev/null || systemctl is-active --quiet redis 2>/dev/null; then
                return 0
            else
                # Try start
                if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
                     sudo systemctl start redis-server &>/dev/null || true
                     sleep 1
                     systemctl is-active --quiet redis-server 2>/dev/null && return 0
                fi
                return 1
            fi
            ;;
        certbot)
            command -v certbot &>/dev/null && return 0 || return 1
            ;;
        *)
            # For other apps, check if Docker container exists and is running
            if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
                 if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${app_name}$"; then
                    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${app_name}$"; then
                        return 0
                    else
                        # specific app container stopped - try start
                        docker start "$app_name" &>/dev/null || true
                        sleep 2
                        docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${app_name}$" && return 0
                        return 1
                    fi
                 else
                    return 1
                 fi
            else
                return 1
            fi
            ;;
    esac
}

# Function to install dependencies recursively
install_dependencies() {
    local app_name="$1"
    local dependencies=$(get_app_config "$app_name" "dependencies")
    
    # If no dependencies, return
    [ -z "$dependencies" ] && return 0
    
    # Split dependencies by comma
    IFS=',' read -ra DEPS <<< "$dependencies"
    
    for dep in "${DEPS[@]}"; do
        dep=$(echo "$dep" | xargs) # trim whitespace
        
        if ! is_app_installed "$dep"; then
            log_warn "Dependency not installed: $dep"
            log_info "Application '$app_name' requires '$dep'"
            log_info "Installing dependency automatically: $dep"
            echo ""
            
            # Find and run dependency installer
            dep_script=$(find "${SCRIPT_DIR}/apps" -name "$dep" -type d -exec test -f "{}/install.sh" \; -print -quit)
            
            if [ -n "$dep_script" ]; then
                # Install dependency
                bash "${dep_script}/install.sh"
                
                # Verify installation
                if ! is_app_installed "$dep"; then
                    log_error "Failed to install dependency: $dep"
                    log_error "Please install $dep manually and try again"
                    return 1
                fi
                
                log_success "Dependency installed successfully: $dep"
                echo ""
            else
                log_error "Cannot find installer for: $dep"
                log_error "Expected location: apps/*/$dep/install.sh"
                return 1
            fi
        else
            log_success "✓ Dependency already installed: $dep"
        fi
    done
    
    return 0
}

clear
echo "=============================================="
echo "  Instalare Aplicații"
echo "=============================================="
echo ""

# List all available applications
echo "AVAILABLE APPLICATIONS:"
echo ""

counter=1
declare -a apps_list=()

for category in apps/*/; do
    category_name=$(basename "$category")
    echo "[$category_name]"
    
    for app_dir in "$category"*/; do
        if [ -d "$app_dir" ] && [ -f "${app_dir}install.sh" ]; then
            app_name=$(basename "$app_dir")
            apps_list+=("${category_name}/${app_name}")
            
            # Show if installed (disable exit on error for this check)
            # Use subshell to prevent script termination on error
            if (is_app_installed "$app_name") 2>/dev/null; then
                printf "   %2d) %-25s [✓ Installed]\n" "$counter" "$app_name"
            else
                printf "   %2d) %s\n" "$counter" "$app_name"
            fi
            ((counter++))
        fi
    done
    echo ""
done

echo "=============================================="
echo " 0) Exit"
echo "=============================================="
echo ""
read -p "Select application number: " choice

if [ "$choice" = "0" ]; then
    echo "Goodbye!"
    exit 0
fi

if [ "$choice" -ge 1 ] && [ "$choice" -lt "$counter" ]; then
    selected="${apps_list[$((choice-1))]}"
    category=$(dirname "$selected")
    app=$(basename "$selected")
    
    echo ""
    echo "=============================================="
    echo "Installing: $app"
    echo "=============================================="
    echo ""
    
    # Check and install dependencies
    log_step "Checking dependencies..."
    if install_dependencies "$app"; then
        log_success "All dependencies satisfied"
    else
        log_error "Dependency installation failed"
        exit 1
    fi
    echo ""
    
    # Run app installer
    script_path="${SCRIPT_DIR}/apps/${category}/${app}/install.sh"
    
    if [ -f "$script_path" ]; then
        bash "$script_path"
    else
        echo "ERROR: Install script not found: $script_path"
        exit 1
    fi
else
    echo "Invalid selection!"
    exit 1
fi
