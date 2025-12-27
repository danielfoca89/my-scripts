#!/bin/bash

# Simple VPS Orchestrator - Direct script execution
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

clear
echo "=============================================="
echo "      VPS ORCHESTRATOR - Simple Mode"
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
            printf "  %2d) %s\n" "$counter" "$app_name"
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
    echo "Installing: $app"
    echo ""
    
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
