#!/bin/bash

# ==============================================================================
# VPS ORCHESTRATOR v2.0
# Interactive application installer and manager for VPS
# ==============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/menu.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/validators.sh"

# Initialize
init_logging
register_cleanup
check_system_requirements

# Main orchestrator loop
main() {
    while true; do
        show_main_menu
        
        local choice
        choice=$(prompt_selection "0 1 2 3 4 5 6 7 8") || continue
        
        case "$choice" in
            1)
                # Databases category
                handle_category "databases"
                ;;
            2)
                # Automation category
                handle_category "automation"
                ;;
            3)
                # Monitoring category
                handle_category "monitoring"
                ;;
            4)
                # Infrastructure category
                handle_category "infrastructure"
                ;;
            5)
                # Security category
                handle_category "security"
                ;;
            6)
                # System category
                handle_category "system"
                ;;
            7)
                # Manage Secrets
                handle_secrets_menu
                ;;
            8)
                # Help & About
                show_help_menu
                ;;
            0)
                # Exit
                echo ""
                log_info "Thank you for using VPS Orchestrator!"
                echo ""
                exit 0
                ;;
            *)
                log_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Handle category selection and app installation
handle_category() {
    local category=$1
    push_menu "$(tr '[:lower:]' '[:upper:]' <<< ${category:0:1})${category:1}"
    
    while true; do
        show_category_menu "$category"
        
        # Get list of apps in category
        local apps_dir="${SCRIPT_DIR}/apps/${category}"
        local -a app_list=()
        
        if [ -d "$apps_dir" ]; then
            while IFS= read -r -d '' app_path; do
                app_list+=("$(basename "$app_path")")
            done < <(find "$apps_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
        fi
        
        local app_count=${#app_list[@]}
        
        # Build valid options string
        local valid_options="0 b"
        for ((i=1; i<=app_count; i++)); do
            valid_options="$valid_options $i"
        done
        
        local choice
        choice=$(prompt_selection "$valid_options") || continue
        
        case "$choice" in
            b)
                # Back to main menu
                pop_menu
                return 0
                ;;
            0)
                # Exit
                echo ""
                log_info "Thank you for using VPS Orchestrator!"
                echo ""
                exit 0
                ;;
            *)
                # Install selected app
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$app_count" ]; then
                    local app_name="${app_list[$((choice-1))]}"
                    install_application "$category" "$app_name"
                    pause
                else
                    log_error "Invalid option"
                    sleep 1
                fi
                ;;
        esac
    done
}

# Install an application
install_application() {
    local category=$1
    local app_name=$2
    local app_path="${SCRIPT_DIR}/apps/${category}/${app_name}"
    local install_script="${app_path}/install.sh"
    
    clear
    echo ""
    log_step "Installing: $app_name"
    echo ""
    
    # Check if install script exists
    if [ ! -f "$install_script" ]; then
        log_error "Installation script not found: $install_script"
        return 1
    fi
    
    # Check if already installed
    if has_credentials "$app_name"; then
        echo "${YELLOW}Application already installed.${NC}"
        echo ""
        if ! confirm_action "Reinstall $app_name?"; then
            log_info "Installation cancelled"
            return 0
        fi
    fi
    
    # Make script executable
    chmod +x "$install_script"
    
    # Execute installation script
    export SCRIPT_DIR
    export APP_NAME="$app_name"
    export APP_CATEGORY="$category"
    
    if bash "$install_script"; then
        echo ""
        show_success "$app_name"
        
        # Display credentials if they exist
        if has_credentials "$app_name"; then
            display_connection_info "$app_name"
        fi
        
        log_success "Installation completed successfully!"
    else
        echo ""
        show_error "$app_name" "Installation script failed"
        log_error "Installation failed. Check logs for details."
        return 1
    fi
}

# Handle secrets management menu
handle_secrets_menu() {
    push_menu "Secret Management"
    
    while true; do
        show_secrets_menu
        
        local choice
        choice=$(prompt_selection "0 b 1 2 3 4 5 6 7") || continue
        
        case "$choice" in
            1)
                # List all secrets
                list_all_secrets
                pause
                ;;
            2)
                # Backup secrets
                backup_secrets
                pause
                ;;
            3)
                # View specific app
                echo ""
                echo -n "${YELLOW}Enter application name:${NC} "
                read -r app_name
                if [ -n "$app_name" ]; then
                    display_connection_info "$app_name"
                fi
                pause
                ;;
            4)
                # Regenerate secrets
                echo ""
                echo -n "${YELLOW}Enter application name:${NC} "
                read -r app_name
                if [ -n "$app_name" ]; then
                    regenerate_secrets "$app_name"
                fi
                pause
                ;;
            5)
                # Delete secrets
                echo ""
                echo -n "${YELLOW}Enter application name:${NC} "
                read -r app_name
                if [ -n "$app_name" ]; then
                    delete_secrets "$app_name"
                fi
                pause
                ;;
            6)
                # Export secrets
                echo ""
                echo -n "${YELLOW}Enter application name:${NC} "
                read -r app_name
                echo -n "${YELLOW}Enter output file path:${NC} "
                read -r output_file
                if [ -n "$app_name" ] && [ -n "$output_file" ]; then
                    export_secrets "$app_name" "$output_file"
                fi
                pause
                ;;
            7)
                # Import secrets
                echo ""
                echo -n "${YELLOW}Enter application name:${NC} "
                read -r app_name
                echo -n "${YELLOW}Enter input file path:${NC} "
                read -r input_file
                if [ -n "$app_name" ] && [ -n "$input_file" ]; then
                    import_secrets "$app_name" "$input_file"
                fi
                pause
                ;;
            b)
                # Back to main menu
                pop_menu
                return 0
                ;;
            0)
                # Exit
                echo ""
                log_info "Thank you for using VPS Orchestrator!"
                echo ""
                exit 0
                ;;
            *)
                log_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list-secrets)
                list_all_secrets
                exit 0
                ;;
            --backup-secrets)
                backup_secrets
                exit 0
                ;;
            --regenerate)
                if [ -n "${2:-}" ]; then
                    regenerate_secrets "$2"
                    exit 0
                else
                    log_error "Application name required"
                    exit 1
                fi
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                echo "VPS Orchestrator v2.0"
                exit 0
                ;;
            --debug)
                export DEBUG=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

# Show usage information
show_usage() {
    cat << EOF

VPS Orchestrator v2.0 - Interactive VPS Application Manager

Usage: ./orchestrator.sh [OPTIONS]

Options:
    --list-secrets          List all stored credentials
    --backup-secrets        Create backup of all secrets
    --regenerate APP        Regenerate secrets for APP
    --debug                 Enable debug mode
    --help, -h              Show this help message
    --version, -v           Show version information

Examples:
    ./orchestrator.sh                      Start interactive menu
    ./orchestrator.sh --list-secrets       List all credentials
    ./orchestrator.sh --regenerate postgres Regenerate PostgreSQL secrets

For more information, visit: https://github.com/danielfoca89/my-scripts

EOF
}

# Entry point
if [ $# -gt 0 ]; then
    parse_arguments "$@"
fi

main
