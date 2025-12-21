#!/bin/bash
# ==========================================
# ARCANE (Infrastructure Manager) INSTALLER
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../../lib/utils.sh" ]; then
    source "$SCRIPT_DIR/../../lib/utils.sh"
elif [ -f "/tmp/lib/utils.sh" ]; then
    source "/tmp/lib/utils.sh"
else
    echo "Error: utils.sh not found."
    exit 1
fi

log_info ">>> STARTING ARCANE INFRASTRUCTURE MANAGER INSTALLATION <<<"

# 1. Verificare Critică: Docker trebuie să fie instalat
require_docker

# 2. Pregătire Directoare
# Arcane are nevoie de un loc unde să își țină baza de date și config-urile
INSTALL_DIR="/opt/arcane"
DATA_DIR="$INSTALL_DIR/data"

log_info "Creating Arcane directories at $DATA_DIR..."
run_sudo mkdir -p "$DATA_DIR"
run_sudo chmod 777 "$DATA_DIR"

# 3. Lansare Container (Modul Manager)
log_info "Deploying Arcane Manager Container..."

# ATENȚIE: 
# - Montăm /var/run/docker.sock: Asta îi dă puterea să creeze/șteargă alte containere (Esențial pentru un Manager)
# - Port: Folosim 3000. Asigură-te că nu ai instalat Grafana pe 3000 (l-am mutat pe 3100, deci e ok).

run_sudo docker run -d \
    --name arcane \
    --restart unless-stopped \
    -p 3000:3000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$DATA_DIR":/app/data \
    -e NODE_ENV=production \
    ghcr.io/arcane-app/arcane:latest
    
    # Notă: Dacă imaginea nu pornește, verifică pe https://getarcane.app/docs 
    # dacă numele imaginii s-a schimbat (ex: uneori e 'arcane/engine').

# 4. Configurare Firewall
open_port 3000 "Arcane Management Dashboard"

log_info "Arcane Manager installed."
log_info "   - URL: http://YOUR_IP:3000"
log_info "   - Mode: Infrastructure Manager (Docker Socket Mounted)"