# Uptime Kuma

**Category**: Docker
**Script Path**: `apps/docker/uptime-kuma/install.sh`

## Description
Uptime Kuma is a self-hosted monitoring tool like "Uptime Robot". It allows you to monitor HTTP(s), TCP, Ping, DNS Record, Push, Steam Game Server, and Docker Containers.

## Dependencies
*   **Docker Engine**: Required (`require_docker`).

## Installation Process

### 1. Storage Setup
*   Creates a named Docker volume: `uptime-kuma`.

### 2. Container Deployment
Deploys `louislam/uptime-kuma:1` with:
*   **Container Name**: `uptime-kuma`
*   **Restart Policy**: `always`
*   **Network**: `vps_network`
*   **Port Mapping**:
    *   Host `3001` -> Container `3001`.
*   **Volume Mounts**:
    *   `uptime-kuma:/app/data`: Persists monitoring history and settings.

### 3. Firewall Configuration
*   Opens TCP port **3001** via UFW.

## Usage
*   **Dashboard URL**: `http://<VPS_IP>:3001`
