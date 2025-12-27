#!/bin/bash

# ==============================================================================
# VPS HEALTH CHECK
# Checks status of all installed services and system resources
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

SECRETS_DIR="${HOME}/.vps-secrets"

print_header() {
    echo "=============================================="
    echo "  VPS Health Check - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    echo ""
}

check_system_resources() {
    echo "[SYSTEM RESOURCES]"
    echo ""
    
    # Disk space
    echo "Disk Usage:"
    df -h / | awk 'NR==1 {print "  " $0} NR==2 {print "  " $0}'
    echo ""
    
    # Memory
    echo "Memory:"
    free -h | awk 'NR==1 {print "  " $0} NR==2 {print "  " $0}'
    echo ""
    
    # CPU Load
    echo "CPU Load:"
    echo "  $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
}

check_docker_containers() {
    echo "[DOCKER CONTAINERS]"
    echo ""
    
    if ! command -v docker &> /dev/null; then
        echo "  Docker not installed"
        echo ""
        return
    fi
    
    if ! docker ps &> /dev/null; then
        echo "  Docker daemon not running"
        echo ""
        return
    fi
    
    local containers=$(docker ps -a --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
        echo "  No containers found"
        echo ""
        return
    fi
    
    printf "  %-25s %-15s %-10s\n" "NAME" "STATUS" "HEALTH"
    printf "  %-25s %-15s %-10s\n" "----" "------" "------"
    
    while IFS= read -r container; do
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || echo "none")
        
        printf "  %-25s %-15s %-10s\n" "$container" "$status" "$health"
    done <<< "$containers"
    
    echo ""
}

check_native_services() {
    echo "[NATIVE SERVICES]"
    echo ""
    
    local services=("nginx" "redis-server" "fail2ban" "wg-quick@wg0")
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            printf "  %-25s %s\n" "$service" "$status"
        fi
    done
    
    echo ""
}

check_network_ports() {
    echo "[NETWORK PORTS]"
    echo ""
    
    if command -v ss &> /dev/null; then
        echo "  Listening ports:"
        ss -tuln | grep LISTEN | awk '{print "    " $5}' | sort -u
    elif command -v netstat &> /dev/null; then
        echo "  Listening ports:"
        netstat -tuln | grep LISTEN | awk '{print "    " $4}' | sort -u
    else
        echo "  ss/netstat not available"
    fi
    
    echo ""
}

check_credentials() {
    echo "[CREDENTIALS]"
    echo ""
    
    if [ ! -d "$SECRETS_DIR" ]; then
        echo "  Secrets directory not found"
        echo ""
        return
    fi
    
    local count=$(ls -1 "${SECRETS_DIR}"/.env_* 2>/dev/null | wc -l)
    echo "  Stored credentials: $count apps"
    
    if [ $count -gt 0 ]; then
        echo "  Applications:"
        for file in "${SECRETS_DIR}"/.env_*; do
            local app=$(basename "$file" | sed 's/^\.env_//')
            echo "    - $app"
        done
    fi
    
    echo ""
}

check_ssl_certificates() {
    echo "[SSL CERTIFICATES]"
    echo ""
    
    local certbot_dir="/etc/letsencrypt/live"
    
    if [ ! -d "$certbot_dir" ]; then
        echo "  No SSL certificates found"
        echo ""
        return
    fi
    
    local domains=$(ls -1 "$certbot_dir" 2>/dev/null | grep -v README)
    
    if [ -z "$domains" ]; then
        echo "  No SSL certificates found"
        echo ""
        return
    fi
    
    printf "  %-30s %-15s\n" "DOMAIN" "EXPIRES"
    printf "  %-30s %-15s\n" "------" "-------"
    
    while IFS= read -r domain; do
        if [ -f "${certbot_dir}/${domain}/cert.pem" ]; then
            local expiry=$(openssl x509 -enddate -noout -in "${certbot_dir}/${domain}/cert.pem" 2>/dev/null | cut -d= -f2 || echo "unknown")
            printf "  %-30s %s\n" "$domain" "$expiry"
        fi
    done <<< "$domains"
    
    echo ""
}

check_backups() {
    echo "[BACKUPS]"
    echo ""
    
    # Credentials backups
    local backup_dir="${SECRETS_DIR}/.backup"
    if [ -d "$backup_dir" ]; then
        local backup_count=$(ls -1 "$backup_dir"/*.tar.gz 2>/dev/null | wc -l)
        echo "  Credential backups: $backup_count"
        
        if [ $backup_count -gt 0 ]; then
            local latest=$(ls -t "$backup_dir"/*.tar.gz 2>/dev/null | head -1)
            if [ -n "$latest" ]; then
                local latest_date=$(stat -c %y "$latest" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
                echo "  Latest backup: $latest_date"
            fi
        fi
    else
        echo "  No credential backups found"
    fi
    
    echo ""
    
    # Database backups
    local db_backup_dir="/opt/backups"
    if [ -d "$db_backup_dir" ]; then
        local db_backup_count=$(find "$db_backup_dir" -type f -name "*.sql*" -o -name "*.dump*" 2>/dev/null | wc -l)
        echo "  Database backups: $db_backup_count"
        
        if [ $db_backup_count -gt 0 ]; then
            local latest_db=$(find "$db_backup_dir" -type f \( -name "*.sql*" -o -name "*.dump*" \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
            if [ -n "$latest_db" ]; then
                local latest_db_date=$(stat -c %y "$latest_db" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
                echo "  Latest DB backup: $latest_db_date"
            fi
        fi
    else
        echo "  No database backups found"
    fi
    
    echo ""
}

# Main execution
main() {
    print_header
    check_system_resources
    check_docker_containers
    check_native_services
    check_network_ports
    check_credentials
    check_ssl_certificates
    check_backups
    
    echo "=============================================="
    echo "  Health check completed"
    echo "=============================================="
}

main "$@"
