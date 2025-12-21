# PostgreSQL

**Category**: Docker
**Script Path**: `apps/docker/postgres/install.sh`

## Description
PostgreSQL is a powerful, open source object-relational database system. This script deploys a standalone PostgreSQL instance.

## Dependencies
*   **Docker Engine**: Required (`require_dependency "docker/engine"`).

## Installation Process

### 1. Network Setup
*   Connects to the `vps_network`.

### 2. Credential Management
*   Generates a strong `DB_PASSWORD`.
*   Stores it in `$HOME/.vps-secrets/.env_postgresql` under `POSTGRES_PASSWORD`.

### 3. Directory Setup
*   **Base Directory**: `/opt/database/postgresql`
*   **Data Directory**: `/opt/database/postgresql/data`

### 4. Container Deployment
Deploys `postgres:latest` with:
*   **Container Name**: `postgresql-server`
*   **Network**: `vps_network`
*   **Port Mapping**:
    *   Host `5432` -> Container `5432`.
*   **Environment Variables**:
    *   `POSTGRES_PASSWORD`: Injected from secrets.
*   **Volume Mounts**:
    *   `/opt/database/postgresql/data:/var/lib/postgresql/data`

### 5. Firewall Configuration
*   Opens TCP port **5432** via UFW.

## Usage
*   **Connection String**: `postgresql://postgres:<PASSWORD>@<VPS_IP>:5432`
*   **Internal Hostname**: `postgresql-server`
