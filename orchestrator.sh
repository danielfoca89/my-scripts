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

# Function to check if an app is installed
is_app_installed() {
    local app_name="$1"
    
    case "$app_name" in
        docker-engine)
            check_docker 2>/dev/null && return 0 || return 1
            ;;
        nginx)
            systemctl is-active --quiet nginx 2>/dev/null && return 0 || return 1
            ;;
        postgres)
            docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^postgres$" && return 0 || return 1
            ;;
        redis)
            systemctl is-active --quiet redis-server 2>/dev/null || systemctl is-active --quiet redis 2>/dev/null && return 0 || return 1
            ;;
        certbot)
            command -v certbot &>/dev/null && return 0 || return 1
            ;;
        *)
            # For other apps, check if Docker container exists
            if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${app_name}$"; then
                return 0
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
            
            if confirm_action "Install $dep now?"; then
                log_info "Installing dependency: $dep"
                
                # Find and run dependency installer
                dep_script=$(find "${SCRIPT_DIR}/apps" -name "$dep" -type d -exec test -f "{}/install.sh" \; -print -quit)
                
                if [ -n "$dep_script" ]; then
                    bash "${dep_script}/install.sh"
                    
                    if ! is_app_installed "$dep"; then
                        log_error "Failed to install dependency: $dep"
                        return 1
                    fi
                    log_success "Dependency installed: $dep"
                else
                    log_error "Cannot find installer for: $dep"
                    return 1
                fi
            else
                log_error "Cannot proceed without dependency: $dep"
                return 1
            fi
        else
            log_success "Dependency already installed: $dep"
        fi
    done
    
    return 0
}

clear
echo "=============================================="
echo "    VPS ORCHESTRATOR - Smart Mode"
echo "    Automatic Dependency Management"
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
            
            # Show if installed
            if is_app_installed "$app_name"; then
                printf "  %2d) %s ✓\n" "$counter" "$app_name"
            else
                printf "  %2d) %s\n" "$counter" "$app_name"
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
