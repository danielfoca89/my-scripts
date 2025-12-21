# Portainer

**Category**: Docker
**Script Path**: `apps/docker/portainer/install.sh`

## Description
Portainer is a lightweight management UI which allows you to easily manage your different Docker environments (containers, images, networks, volumes) through a web interface.

## Dependencies
*   **Docker Engine**: Required (`require_docker`).

## Installation Process

### 1. Storage Setup
*   Creates a named Docker volume: `portainer_data`. This ensures that Portainer's configuration (users, environments) persists even if the container is recreated.

### 2. Container Deployment
Deploys `portainer/portainer-ce:latest` with:
*   **Container Name**: `portainer`
*   **Restart Policy**: `always`
*   **Volume Mounts**:
    *   `/var/run/docker.sock:/var/run/docker.sock`: **Critical**. Allows Portainer to manage the host's Docker instance.
    *   `portainer_data:/data`: Persists application data.
*   **Port Mapping**:
    *   Host `8000` -> Container `8000` (Edge Agent tunnel).
    *   Host `9443` -> Container `9443` (HTTPS Web UI).

### 3. Firewall Configuration
*   Opens TCP port **9443** via UFW.

## Usage
*   **Dashboard URL**: `https://<VPS_IP>:9443`
*   **First Run**: You will be asked to create an admin user and password.
