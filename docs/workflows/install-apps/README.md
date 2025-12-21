# Install & Secure Applications Workflow

**File Path**: `.github/workflows/install-apps.yml`

## Description
This workflow is the **application deployer**. It allows you to select any application (Docker or Host-based) from a dropdown menu and deploy it to your hardened VPS. It handles the dynamic resolution of script paths and the secure transfer of the entire script library.

## Inputs
| Input | Description | Required |
| :--- | :--- | :--- |
| `vps_ip` | The Public IP of the target VPS. | Yes |
| `ssh_user` | The admin username (created in the hardening workflow). | Yes |
| `ssh_password` | The admin password. | Yes |
| `ssh_port` | The custom SSH port (e.g., 2222). | Yes |
| `selection` | The application to install (Dropdown list). | Yes |
| `domain` | Domain name (Required for Web Apps/Certbot). | Optional |
| `email` | Email address (Required for SSL). | Optional |
| `wg_password` | Password for WireGuard Web UI. | Optional |

## Execution Flow

### 1. Dynamic Path Resolution
The workflow uses a smart resolution step to find the correct script based on the user's selection.
*   **Input**: `Docker > n8n Automation | docker/n8n`
*   **Logic**: Extracts `docker/n8n`, searches the `apps/` directory for `install.sh` inside that path.
*   **Result**: Sets `REMOTE_SCRIPT_PATH` to `docker/n8n/install.sh`.

### 2. Library Upload
*   Uses `scp` (Secure Copy) to upload the entire `apps/` and `lib/` directories to `/tmp/` on the VPS.
*   This ensures that the installation script has access to all helper functions (`lib/utils.sh`) and configuration snippets (`lib/config/`).

### 3. Remote Execution
Connects to the VPS via SSH and executes the specific installation script.
*   **Command**:
    ```bash
    export DOMAIN="${{ inputs.domain }}"
    export EMAIL="${{ inputs.email }}"
    export WG_PASSWORD="${{ inputs.wg_password }}"
    
    chmod +x /tmp/apps/$REMOTE_SCRIPT_PATH
    sudo -E /tmp/apps/$REMOTE_SCRIPT_PATH
    ```
*   **Environment Variables**: Passes inputs (Domain, Email, etc.) as environment variables so the scripts can consume them non-interactively.

### 4. Cleanup
*   Removes the temporary files (`/tmp/apps`, `/tmp/lib`) from the VPS to keep the system clean.

## Supported Applications
The workflow currently supports deploying:
*   **Docker**: Arcane, Engine, Grafana, MariaDB, MongoDB, n8n, Netdata, Portainer, Postgres, Prometheus, Redis, Uptime Kuma.
*   **Host**: Certbot, Log Maintenance, Nginx, NodeJS, Security Audit, WireGuard.
