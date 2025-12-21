# Redis

**Category**: Docker
**Script Path**: `apps/docker/redis/install.sh`

## Description
Redis is an open source (BSD licensed), in-memory data structure store, used as a database, cache, and message broker. This script deploys a secured Redis instance.

## Dependencies
*   **Docker Engine**: Required (`require_dependency "docker/engine"`).

## Installation Process

### 1. Network Setup
*   Connects to the `vps_network`.

### 2. Credential Management
*   Generates a strong `REDIS_PASSWORD`.
*   Stores it in `$HOME/.vps-secrets/.env_redis`.

### 3. Directory Setup
*   **Base Directory**: `/opt/database/redis`
*   **Data Directory**: `/opt/database/redis/data`

### 4. Container Deployment
Deploys `redis:latest` with:
*   **Container Name**: `redis-server`
*   **Network**: `vps_network`
*   **Port Mapping**:
    *   Host `6379` -> Container `6379`.
*   **Command Override**: `redis-server --requirepass "$REDIS_PASSWORD"`
    *   This forces Redis to require authentication, which is crucial for security.
*   **Volume Mounts**:
    *   `/opt/database/redis/data:/data`

### 5. Firewall Configuration
*   Opens TCP port **6379** via UFW.

## Usage
*   **Connection String**: `redis://:<PASSWORD>@<VPS_IP>:6379`
*   **Internal Hostname**: `redis-server`
