# WireGuard VPN

**Category**: Host (Docker-based)
**Script Path**: `apps/host/wireguard/install.sh`

## Description
WireGuard is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography. This installation uses `wg-easy`, a Docker container that provides both the WireGuard VPN service and a beautiful web-based UI for managing clients.

## Dependencies
*   **Docker Engine**: Required (`require_docker`).

## Installation Process

### 1. IP Detection
*   Automatically detects the VPS Public IP using `curl -s ifconfig.me`. This is required for the VPN configuration file generation.

### 2. Credential Management
*   Generates a random `WG_PASSWORD` for the Web UI.
*   Stores it in `$HOME/.vps-secrets/.env_wireguard`.

### 3. Container Deployment
Deploys `ghcr.io/wg-easy/wg-easy` with:
*   **Container Name**: `wg-easy`
*   **Network**: Host networking is NOT used; ports are mapped explicitly.
*   **Capabilities**:
    *   `NET_ADMIN`: Required to modify network interfaces.
    *   `SYS_MODULE`: Required to load kernel modules.
*   **Sysctl**:
    *   `net.ipv4.ip_forward=1`: Enables IP forwarding (routing).
*   **Port Mapping**:
    *   `51820:51820/udp`: The VPN tunnel port.
    *   `51821:51821/tcp`: The Web UI port.
*   **Volume Mounts**:
    *   `~/.wg-easy:/etc/wireguard`: Persists configuration and client keys.

### 4. Firewall Configuration
*   Opens UDP port **51820** (VPN Traffic).
*   Opens TCP port **51821** (Web UI).

## Usage
*   **Web UI**: `http://<VPS_IP>:51821`
*   **Password**: See `$HOME/.vps-secrets/.env_wireguard`
*   **Connect Client**: Create a client in the UI and scan the QR code with the WireGuard mobile app.
