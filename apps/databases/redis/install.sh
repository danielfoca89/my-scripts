#!/bin/bash

# ==============================================================================
# REDIS CACHE/DATABASE INSTALLATION (NATIVE)
# Installs Redis directly on host for maximum performance and low latency
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/os-detect.sh"

APP_NAME="redis"
CONF_FILE="/etc/redis/redis.conf"
DATA_DIR="/var/lib/redis"
LOG_FILE="/var/log/redis/redis-server.log"

log_info "═══════════════════════════════════════════"
log_info "  Installing Redis Cache/Database (Native)"
log_info "═══════════════════════════════════════════"
echo ""

# Detect OS
log_step "Step 1: Detecting operating system"
detect_os
log_success "OS detected: $OS_TYPE"
log_info "Package manager: $PACKAGE_MANAGER"
echo ""

# Check if already installed
if systemctl is-active --quiet redis-server 2>/dev/null || systemctl is-active --quiet redis 2>/dev/null; then
    log_warn "Redis is already running"
    if confirm_action "Reinstall/Reconfigure?"; then
        log_info "Proceeding with reconfiguration..."
    else
        log_info "Installation cancelled"
        exit 0
    fi
fi
echo ""

# Install Redis
log_step "Step 2: Installing Redis"
pkg_update

if is_debian_based; then
    pkg_install redis-server redis-tools
elif is_rhel_based; then
    pkg_install epel-release
    pkg_install redis
else
    log_error "Unsupported OS: $OS_ID"
    exit 1
fi

log_success "Redis installed"
echo ""

# Manage credentials
log_step "Step 3: Setting up Redis password"

if has_credentials "$APP_NAME"; then
    log_info "Using existing password from credentials store"
    REDIS_PASSWORD=$(get_secret "$APP_NAME" "REDIS_PASSWORD")
else
    log_info "Generating secure password..."
    REDIS_PASSWORD=$(generate_secret "REDIS_PASSWORD")
    save_credentials "$APP_NAME" "REDIS_PASSWORD=$REDIS_PASSWORD"
    log_success "Password saved to credentials store"
fi
echo ""

# Configure Redis
log_step "Step 4: Configuring Redis"

# Backup original config
if [ -f "$CONF_FILE" ]; then
    run_sudo cp "$CONF_FILE" "${CONF_FILE}.backup_$(date +%Y%m%d_%H%M%S)"
fi

# Create optimized Redis configuration
run_sudo tee "$CONF_FILE" > /dev/null <<EOF
# Redis Configuration - Optimized for Production

# Network
bind 127.0.0.1 ::1
port 6379
protected-mode yes
timeout 0
tcp-keepalive 300

# General
daemonize yes
supervised systemd
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile $LOG_FILE
databases 16

# Snapshotting (RDB persistence)
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir $DATA_DIR

# Replication
replica-read-only yes

# Security
requirepass $REDIS_PASSWORD

# Limits
maxclients 10000
maxmemory 256mb
maxmemory-policy allkeys-lru

# Append Only File (AOF persistence)
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Slow log
slowlog-log-slower-than 10000
slowlog-max-len 128

# Advanced config
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
EOF

run_sudo chown redis:redis "$CONF_FILE"
run_sudo chmod 640 "$CONF_FILE"
log_success "Redis configured"
echo ""

# Setup directories and permissions
log_step "Step 5: Setting up directories"
run_sudo mkdir -p "$DATA_DIR"
run_sudo mkdir -p "$(dirname "$LOG_FILE")"
run_sudo chown -R redis:redis "$DATA_DIR"
run_sudo chown -R redis:redis "$(dirname "$LOG_FILE")"
run_sudo chmod 750 "$DATA_DIR"
log_success "Directories configured"
echo ""

# Configure systemd service
log_step "Step 6: Configuring systemd service"

# Determine service name (different on Ubuntu vs CentOS)
if [ "$PACKAGE_MANAGER" = "apt" ]; then
    SERVICE_NAME="redis-server"
else
    SERVICE_NAME="redis"
fi

run_sudo systemctl enable "$SERVICE_NAME"
run_sudo systemctl restart "$SERVICE_NAME"

# Wait for Redis to start
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_success "Redis is running"
else
    log_error "Failed to start Redis"
    log_info "Check logs: sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
echo ""

# Test connection
log_step "Step 7: Testing Redis connection"
if redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q "PONG"; then
    log_success "Redis connection test passed"
else
    log_error "Redis connection test failed"
    exit 1
fi
echo ""

# Display installation info
log_success "═══════════════════════════════════════════"
log_success "  Redis Installation Complete!"
log_success "═══════════════════════════════════════════"
echo ""

log_info "Connection Information:"
echo "  Host:     127.0.0.1 (localhost only)"
echo "  Port:     6379"
echo "  Password: $REDIS_PASSWORD"
echo ""

log_info "Configuration:"
echo "  Config File:   $CONF_FILE"
echo "  Data Dir:      $DATA_DIR"
echo "  Log File:      $LOG_FILE"
echo "  Service Name:  $SERVICE_NAME"
echo ""

log_info "Connection Examples:"
cat <<'EXAMPLES'
  # CLI with password:
  redis-cli -a YOUR_PASSWORD
  
  # Test connection:
  redis-cli -a YOUR_PASSWORD ping
  
  # Get info:
  redis-cli -a YOUR_PASSWORD info
  
  # Monitor commands:
  redis-cli -a YOUR_PASSWORD monitor
  
  # NodeJS connection:
  const redis = require('redis');
  const client = redis.createClient({
      host: '127.0.0.1',
      port: 6379,
      password: 'YOUR_PASSWORD'
  });
  
  # Python connection:
  import redis
  r = redis.Redis(
      host='127.0.0.1',
      port=6379,
      password='YOUR_PASSWORD'
  )
EXAMPLES

echo ""
log_info "Useful commands:"
echo "  sudo systemctl status $SERVICE_NAME    # Check status"
echo "  sudo systemctl restart $SERVICE_NAME   # Restart"
echo "  sudo systemctl stop $SERVICE_NAME      # Stop"
echo "  redis-cli -a PASSWORD info            # Get info"
echo "  redis-cli -a PASSWORD dbsize          # Get key count"
echo "  sudo tail -f $LOG_FILE                # View logs"
echo ""

log_info "Performance tuning:"
echo "  • Adjust maxmemory in $CONF_FILE based on available RAM"
echo "  • Monitor memory: redis-cli -a PASSWORD info memory"
echo "  • Monitor stats: redis-cli -a PASSWORD info stats"
echo ""

log_warn "Security Note:"
echo "  • Redis is bound to localhost only (secure)"
echo "  • Password authentication is enabled"
echo "  • Credentials saved in: ~/.vps-secrets/.env_$APP_NAME"
echo "  • To allow remote access, edit bind in $CONF_FILE"
echo ""

log_info "Backup commands:"
echo "  # Manual backup:"
echo "  redis-cli -a PASSWORD save"
echo "  sudo cp $DATA_DIR/dump.rdb /backup/location/"
echo ""
echo "  # Scheduled backup with cron:"
echo "  0 2 * * * redis-cli -a PASSWORD save && cp $DATA_DIR/dump.rdb /backup/redis-\$(date +\\%Y\\%m\\%d).rdb"
echo ""

read -p "Press Enter to continue..."
