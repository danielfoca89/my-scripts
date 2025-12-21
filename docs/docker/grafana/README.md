# Grafana

**Category**: Docker
**Script Path**: `apps/docker/grafana/install.sh`

## Description
Grafana is the open-source analytics and monitoring solution for every database. This script deploys Grafana in a Docker container, configured to connect to the internal VPS network for secure access to data sources like Prometheus or PostgreSQL.

## Dependencies
*   **Docker Engine**: Required (`require_docker`).

## Installation Process

### 1. Network Setup
*   Ensures the `vps_network` Docker network exists. This allows Grafana to resolve other container names (e.g., `prometheus`, `postgres`) by hostname.

### 2. Directory & Permissions
*   **Base Directory**: `/opt/monitoring/grafana`
*   **Data Directory**: `/opt/monitoring/grafana/data`
*   **Permissions**: Changes ownership to user `472:472` (Grafana's internal user) to ensure write access.

### 3. Credential Management
*   Generates a secure random password for the `admin` user if one does not exist.
*   Stores the password in `$HOME/.vps-secrets/.env_grafana` under `GF_SECURITY_ADMIN_PASSWORD`.

### 4. Container Deployment
Deploys `grafana/grafana:latest` with:
*   **Container Name**: `grafana`
*   **Network**: `vps_network`
*   **Port Mapping**:
    *   Host `3100` -> Container `3000`.
    *   *Note*: We map to host port **3100** to avoid conflicts with other apps (like Node.js/Next.js) that commonly use port 3000.
*   **Environment Variables**:
    *   `GF_SECURITY_ADMIN_PASSWORD`: Injected from the secrets file.
*   **Volume Mounts**:
    *   `/opt/monitoring/grafana/data:/var/lib/grafana`: Persists dashboards, users, and settings.

### 5. Firewall Configuration
*   Opens TCP port **3100** via UFW.

## Usage
*   **URL**: `http://<VPS_IP>:3100`
*   **Login**:
    *   User: `admin`
    *   Password: See `$HOME/.vps-secrets/.env_grafana`
