# n8n Automation

**Category**: Docker
**Script Path**: `apps/docker/n8n/install.sh`

## Description
n8n is a fair-code workflow automation tool that allows you to connect apps and automate workflows. This is a **complex installation** that automatically provisions a dedicated PostgreSQL database, configures authentication, and optionally sets up an Nginx Reverse Proxy with SSL.

## Dependencies
*   **Docker Engine**: Required (`require_dependency "docker/engine"`).
*   **PostgreSQL**: Required (`require_dependency "docker/postgres"`). The script will trigger the installation of Postgres if it is not already present.

## Installation Process

### 1. Argument Parsing
Accepts optional arguments for automatic domain configuration:
*   `--domain <domain>`: The domain name (e.g., `n8n.example.com`).
*   `--email <email>`: Email for Let's Encrypt SSL.

### 2. Database Provisioning (Auto-Magic)
*   Checks for the `postgresql-server` container.
*   Generates a random **Database Name** and **Database User** for n8n.
*   Connects to the Postgres container via `docker exec` and executes SQL commands to:
    1.  Create the User.
    2.  Create the Database.
    3.  Grant privileges.
*   This ensures n8n has a dedicated, isolated database without manual intervention.

### 3. Credential Management
Generates and stores the following in `$HOME/.vps-secrets/.env_n8n`:
*   `N8N_DB_PASSWORD`: Password for the Postgres user.
*   `N8N_ENCRYPTION_KEY`: Key for encrypting credentials within n8n.
*   `N8N_BASIC_AUTH_USER`: Username for n8n login.
*   `N8N_BASIC_AUTH_PASSWORD`: Password for n8n login.

### 4. Container Deployment
Deploys `docker.n8n.io/n8nio/n8n` with:
*   **Container Name**: `n8n`
*   **Network**: `vps_network` (to communicate with `postgresql-server`).
*   **Port Mapping**:
    *   Host `5678` -> Container `5678`.
*   **Environment Variables**:
    *   `DB_TYPE=postgresdb`
    *   `DB_POSTGRESDB_HOST=postgresql-server`
    *   `N8N_BASIC_AUTH_ACTIVE=true`
    *   Plus all generated credentials.
*   **Volume Mounts**:
    *   `$HOME/.n8n-data:/home/node/.n8n`: Persists workflows and settings.

### 5. Reverse Proxy & SSL (Optional)
If `--domain` and `--email` are provided (or entered interactively):
*   Configures n8n with `WEBHOOK_URL` and `N8N_EDITOR_BASE_URL`.
*   Calls the `setup_nginx_proxy` function (from `utils.sh`) to:
    1.  Generate an Nginx server block for the domain.
    2.  Proxy traffic to `http://localhost:5678`.
    3.  Request a Let's Encrypt SSL certificate via Certbot.

### 6. Firewall Configuration
*   Opens TCP port **5678** via UFW (if not using Nginx/SSL).

## Usage
*   **Direct Access**: `http://<VPS_IP>:5678`
*   **Domain Access**: `https://<YOUR_DOMAIN>` (if configured)
*   **Login**: Use the generated Basic Auth credentials found in `.vps-secrets`.
