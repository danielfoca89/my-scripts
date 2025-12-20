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

log_info ">>> STARTING PROMETHEUS & NODE EXPORTER INSTALLATION <<<"

if ! command -v docker >/dev/null; then
    log_error "Docker is not installed."
    exit 1
fi

# 1. Create Shared Network (Idempotent)
# Dacă rețeaua există, comanda nu va da eroare (|| true)
log_info "Ensuring 'monitoring_net' Docker network exists..."
run_sudo docker network create monitoring_net 2>/dev/null || true

# 2. Prepare Directories
BASE_DIR="/opt/monitoring/prometheus"
run_sudo mkdir -p "$BASE_DIR/data"
run_sudo mkdir -p "$BASE_DIR/config"

# 3. Create Configuration
log_info "Creating Prometheus Config..."
cat <<EOF | run_sudo tee "$BASE_DIR/config/prometheus.yml"
global:
  scrape_interval: 15s

scrape_configs:
  # Monitor the host itself via Node Exporter
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  
  # Monitor Prometheus internals
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# 4. Run Prometheus Container
log_info "Deploying Prometheus Container..."
run_sudo docker run -d \
    --name prometheus \
    --network monitoring_net \
    --restart unless-stopped \
    -v "$BASE_DIR/config/prometheus.yml":/etc/prometheus/prometheus.yml \
    -v "$BASE_DIR/data":/prometheus \
    prom/prometheus:latest

# 5. Run Node Exporter (The Agent that collects CPU/RAM stats)
log_info "Deploying Node Exporter..."
run_sudo docker run -d \
    --name node-exporter \
    --network monitoring_net \
    --restart unless-stopped \
    prom/node-exporter:latest

log_info "Prometheus & Node Exporter installed."
log_info "   - Network: monitoring_net"
log_info "   - Status: Internal access only (Secure)."