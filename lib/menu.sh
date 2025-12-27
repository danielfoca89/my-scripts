#!/bin/bash

# ==============================================================================
# INTERACTIVE MENU SYSTEM
# Provides hierarchical navigation with breadcrumbs and user-friendly interface
# ==============================================================================

set -euo pipefail

# Navigation state
declare -a MENU_STACK=()
CURRENT_CATEGORY=""

# Print ASCII banner
print_banner() {
    cat << 'EOF'
╔═════════════════════════════════════════════════════════════╗
║           VPS ORCHESTRATOR v2.0 - Professional Setup       ║
╚═════════════════════════════════════════════════════════════╝
EOF
}

# Print breadcrumb navigation
print_breadcrumb() {
    local breadcrumb="Main"
    
    if [ ${#MENU_STACK[@]} -gt 0 ]; then
        for item in "${MENU_STACK[@]}"; do
            breadcrumb="${breadcrumb} > ${item}"
        done
    fi
    
    echo ""
    echo "${BLUE}> ${breadcrumb}${NC}"
    echo ""
}

# Clear screen and show header
show_header() {
    clear
    print_banner
    print_breadcrumb
}

# Show main menu
show_main_menu() {
    show_header
    
    echo "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo "${GREEN}                      SELECT CATEGORY${NC}"
    echo "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  ${BLUE}[1]${NC} Databases       - PostgreSQL, MariaDB, MongoDB, Redis"
    echo "  ${BLUE}[2]${NC} Automation      - n8n"
    echo "  ${BLUE}[3]${NC} Monitoring      - Grafana, Prometheus, Netdata, Uptime Kuma"
    echo "  ${BLUE}[4]${NC} Infrastructure  - Docker, Portainer, Nginx, Certbot, Arcane"
    echo "  ${BLUE}[5]${NC} Security        - WireGuard VPN, Fail2ban, Security Audit"
    echo "  ${BLUE}[6]${NC} System          - VPS Setup, Node.js, Log Maintenance"
    echo ""
    echo "${GREEN}─────────────────────────────────────────────────────────────${NC}"
    echo "  ${BLUE}[7]${NC} Manage Secrets"
    echo "  ${BLUE}[8]${NC} Help & About"
    echo "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  ${YELLOW}[0]${NC} Exit"
    echo ""
}

# Show category menu
# Args: $1 = category name
show_category_menu() {
    local category=$1
    CURRENT_CATEGORY="$category"
    
    show_header
    
    local category_icon=""
    local category_title=""
    
    case "$category" in
        databases)
            category_title="DATABASES"
            ;;
        automation)
            category_title="AUTOMATION"
            ;;
        monitoring)
            category_title="MONITORING"
            ;;
        infrastructure)
            category_title="INFRASTRUCTURE"
            ;;
        security)
            category_title="SECURITY"
            ;;
        system)
            category_title="SYSTEM"
            ;;
    esac
    
    echo "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo "${GREEN}                      ${category_title}${NC}"
    echo "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Read applications from config file
    local app_count=0
    local apps_dir="${SCRIPT_DIR}/apps/${category}"
    
    if [ -d "$apps_dir" ]; then
        for app_path in "$apps_dir"/*; do
            if [ -d "$app_path" ]; then
                local app_name=$(basename "$app_path")
                app_count=$((app_count + 1))
                
                # Get app description from config if available
                local description=$(get_app_description "$category" "$app_name")
                
                # Check if already installed
                local status_indicator=""
                if has_credentials "$app_name"; then
                    status_indicator="${GREEN}[+]${NC}"
                else
                    status_indicator="   "
                fi
                
                printf "  ${status_indicator} ${BLUE}[%d]${NC} %-20s - %s\n" "$app_count" "$app_name" "$description"
            fi
        done
    fi
    
    if [ "$app_count" -eq 0 ]; then
        echo "  ${YELLOW}No applications available in this category.${NC}"
    fi
    
    echo ""
    echo "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo "  ${YELLOW}[b]${NC} Back    ${YELLOW}[0]${NC} Exit"
    echo ""
}

# Get application description
# Args: $1 = category, $2 = app_name
get_app_description() {
    local category=$1
    local app_name=$2
    
    case "${category}/${app_name}" in
        databases/postgres) echo "Powerful relational database" ;;
        databases/mariadb) echo "MySQL-compatible database" ;;
        databases/mongodb) echo "NoSQL document database" ;;
        databases/redis) echo "In-memory data store" ;;
        automation/n8n) echo "Workflow automation platform" ;;
        monitoring/grafana) echo "Analytics & monitoring" ;;
        monitoring/prometheus) echo "Metrics & alerting" ;;
        monitoring/netdata) echo "Real-time performance monitoring" ;;
        monitoring/uptime-kuma) echo "Uptime monitoring tool" ;;
        infrastructure/docker-engine) echo "Container runtime" ;;
        infrastructure/portainer) echo "Docker management UI" ;;
        infrastructure/nginx) echo "Web server & reverse proxy" ;;
        infrastructure/certbot) echo "SSL certificate manager" ;;
        infrastructure/arcane) echo "Docker management UI" ;;
        security/wireguard) echo "Modern VPN solution" ;;
        security/security-audit) echo "Security scanning tools" ;;
        security/fail2ban) echo "Intrusion prevention" ;;
        system/setup-vps) echo "Initial VPS configuration" ;;
        system/nodejs) echo "JavaScript runtime" ;;
        system/log-maintenance) echo "Log rotation & cleanup" ;;
        *) echo "Application" ;;
    esac
}

# Show secrets management menu
show_secrets_menu() {
    show_header
    
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo "${GREEN}  🔐 Secret Management${NC}"
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo ""
    echo "  ${BLUE}[1]${NC} List All Secrets       - View stored credentials"
    echo "  ${BLUE}[2]${NC} Backup Secrets         - Create encrypted backup"
    echo "  ${BLUE}[3]${NC} View Specific App      - Display app credentials"
    echo "  ${BLUE}[4]${NC} Regenerate Secrets     - Create new credentials"
    echo "  ${BLUE}[5]${NC} Delete Secrets         - Remove app credentials"
    echo "  ${BLUE}[6]${NC} Export Secrets         - Export for migration"
    echo "  ${BLUE}[7]${NC} Import Secrets         - Import from file"
    echo ""
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo "  ${YELLOW}[b]${NC} Back to Main Menu"
    echo "  ${YELLOW}[0]${NC} Exit"
    echo ""
}

# Show help/about menu
show_help_menu() {
    show_header
    
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo "${GREEN}  Help & Documentation${NC}"
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo ""
    echo "  ${BLUE}Version:${NC} 2.0.0"
    echo "  ${BLUE}Author:${NC}  danielfoca89"
    echo "  ${BLUE}GitHub:${NC}  github.com/danielfoca89/my-scripts"
    echo ""
    echo "${YELLOW}Quick Start:${NC}"
    echo "  1. Select a category from the main menu"
    echo "  2. Choose an application to install"
    echo "  3. Follow the prompts for configuration"
    echo "  4. Credentials are auto-generated and stored in ~/.vps-secrets/"
    echo ""
    echo "${YELLOW}Features:${NC}"
    echo "  + Automatic credential generation"
    echo "  + Secure secret storage"
    echo "  + Docker-based deployments"
    echo "  + Dependency management"
    echo "  + Health checks and validation"
    echo ""
    echo "${YELLOW}Documentation:${NC}"
    echo "  • Usage Guide:    docs/USAGE.md"
    echo "  • Architecture:   docs/ARCHITECTURE.md"
    echo "  • Development:    docs/DEVELOPMENT.md"
    echo ""
    echo "${YELLOW}Secrets Location:${NC}"
    echo "  ${BLUE}${HOME}/.vps-secrets/${NC}"
    echo ""
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Prompt for user selection
# Args: $1 = valid options (space-separated)
prompt_selection() {
    local valid_options=$1
    local choice
    
    echo -n "${YELLOW}Enter your choice:${NC} "
    read -r choice
    
    # Validate input
    if [[ " $valid_options " =~ " $choice " ]]; then
        echo "$choice"
        return 0
    else
        echo "${RED}[X] Invalid option: $choice${NC}" >&2
        sleep 1
        return 1
    fi
}

# Confirm action
# Args: $1 = message
confirm_action() {
    local message=$1
    local choice
    
    echo ""
    echo -n "${YELLOW}${message} (y/n):${NC} "
    read -r choice
    
    [[ "$choice" =~ ^[Yy]$ ]]
}

# Push menu to stack (for breadcrumb navigation)
push_menu() {
    local menu_name=$1
    MENU_STACK+=("$menu_name")
}

# Pop menu from stack
pop_menu() {
    if [ ${#MENU_STACK[@]} -gt 0 ]; then
        unset 'MENU_STACK[-1]'
    fi
}

# Show installation progress
# Args: $1 = app_name, $2 = step_description
show_progress() {
    local app_name=$1
    local step=$2
    
    echo ""
    echo "${BLUE}[${app_name}]${NC} ${step}..."
}

# Show success message
show_success() {
    local app_name=$1
    
    echo ""
    echo "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo "${GREEN}║                                           ║${NC}"
    echo "${GREEN}║  [OK] Installation Successful!             ║${NC}"
    echo "${GREEN}║                                           ║${NC}"
    echo "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo "${BLUE}Application:${NC} ${app_name}"
    echo "${BLUE}Credentials:${NC} ~/.vps-secrets/.env_${app_name}"
    echo ""
}

# Show error message
show_error() {
    local app_name=$1
    local error_msg=$2
    
    echo ""
    echo "${RED}╔═══════════════════════════════════════════╗${NC}"
    echo "${RED}║                                           ║${NC}"
    echo "${RED}║  [FAIL] Installation Failed!               ║${NC}"
    echo "${RED}║                                           ║${NC}"
    echo "${RED}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo "${BLUE}Application:${NC} ${app_name}"
    echo "${RED}Error:${NC} ${error_msg}"
    echo ""
    echo "Check logs for more details."
    echo ""
}

# Wait for user input to continue
pause() {
    echo ""
    read -p "Press Enter to continue..."
}
