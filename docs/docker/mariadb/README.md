# MariaDB

**Category**: Docker
**Script Path**: `apps/docker/mariadb/install.sh`

## Description
MariaDB is a community-developed, commercially supported fork of the MySQL relational database management system. This script deploys a standalone MariaDB instance suitable for general-purpose database needs.

## Dependencies
*   **Docker Engine**: Required (`require_docker`).

## Installation Process

### 1. Network Setup
*   Connects to the `vps_network` to allow other containers (like WordPress or custom apps) to connect via the hostname `mariadb-server`.

### 2. Credential Management
*   Generates a strong `MARIADB_ROOT_PASSWORD`.
*   Stores it in `$HOME/.vps-secrets/.env_mariadb`.

### 3. Directory Setup
*   **Base Directory**: `/opt/database/mariadb`
*   **Data Directory**: `/opt/database/mariadb/data` (Persists DB files)
*   **Config Directory**: `/opt/database/mariadb/config` (For custom `my.cnf`)

### 4. Container Deployment
Deploys `mariadb:latest` with:
*   **Container Name**: `mariadb-server`
*   **Network**: `vps_network`
*   **Port Mapping**:
    *   Host `3306` -> Container `3306`.
*   **Environment Variables**:
    *   `MYSQL_ROOT_PASSWORD`: Injected from secrets.
*   **Volume Mounts**:
    *   `/opt/database/mariadb/data:/var/lib/mysql`

### 5. Firewall Configuration
*   Opens TCP port **3306** via UFW.
*   *Security Note*: If you only need internal access (from other containers), you can manually close this port later.

## Usage
*   **Connection String**: `mysql://root:<PASSWORD>@<VPS_IP>:3306`
*   **Internal Hostname**: `mariadb-server` (for other containers on `vps_network`)
