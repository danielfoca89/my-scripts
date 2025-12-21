# MongoDB

**Category**: Docker
**Script Path**: `apps/docker/mongodb/install.sh`

## Description
MongoDB is a source-available cross-platform document-oriented database program. This script deploys a secured MongoDB instance with authentication enabled by default.

## Dependencies
*   **Docker Engine**: Required (`require_docker`).

## Installation Process

### 1. Network Setup
*   Connects to the `vps_network`.

### 2. Credential Management
*   Generates `MONGO_ROOT_USER` (default: `admin` or random).
*   Generates `MONGO_ROOT_PASSWORD`.
*   Stores credentials in `$HOME/.vps-secrets/.env_mongodb`.

### 3. Directory Setup
*   **Base Directory**: `/opt/database/mongodb`
*   **Data Directory**: `/opt/database/mongodb/data`

### 4. Container Deployment
Deploys `mongo:latest` with:
*   **Container Name**: `mongodb-server`
*   **Network**: `vps_network`
*   **Port Mapping**:
    *   Host `27017` -> Container `27017`.
*   **Environment Variables**:
    *   `MONGO_INITDB_ROOT_USERNAME`: Root username.
    *   `MONGO_INITDB_ROOT_PASSWORD`: Root password.
*   **Volume Mounts**:
    *   `/opt/database/mongodb/data:/data/db`

### 5. Firewall Configuration
*   Opens TCP port **27017** via UFW.

## Usage
*   **Connection String**: `mongodb://<USER>:<PASSWORD>@<VPS_IP>:27017`
*   **Internal Hostname**: `mongodb-server`
