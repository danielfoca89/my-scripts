# Arcane Infrastructure Manager

**Category**: Docker
**Script Path**: `apps/docker/arcane/install.sh`

## Description
Arcane is a self-hosted infrastructure management tool designed to simplify the deployment and management of applications. It acts as a "Manager" container that can spawn and control other Docker containers, making it a powerful tool for orchestrating your VPS services.

## Dependencies
*   **Docker Engine**: Required to run the container (`require_docker`).

## Installation Process

### 1. Prerequisite Check
The script first verifies if Docker is installed on the system. If not, it halts execution (or installs it if triggered via dependency logic).

### 2. Directory Setup
*   **Base Directory**: `/opt/arcane`
*   **Data Directory**: `/opt/arcane/data`
    *   **Permissions**: Set to `777` to ensure the container can write to it regardless of the internal user ID.

### 3. Container Deployment
The script deploys the `ghcr.io/arcane-app/arcane:latest` image with the following configuration:
*   **Container Name**: `arcane`
*   **Restart Policy**: `unless-stopped`
*   **Network Mode**: Bridge (Default)
*   **Environment Variables**:
    *   `NODE_ENV=production`
*   **Volume Mounts**:
    *   `/var/run/docker.sock:/var/run/docker.sock`: **Critical**. This allows Arcane to communicate with the host's Docker Daemon to manage other containers.
    *   `/opt/arcane/data:/app/data`: Persists application data.
*   **Port Mapping**:
    *   Host `3000` -> Container `3000`

### 4. Firewall Configuration
*   Opens TCP port **3000** via UFW to allow access to the web dashboard.

## Usage
*   **Dashboard URL**: `http://<VPS_IP>:3000`
*   **Function**: Use the web interface to deploy new apps, manage existing containers, and view logs.
