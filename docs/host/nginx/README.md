# Nginx Web Server

**Category**: Host
**Script Path**: `apps/host/nginx/install.sh`

## Description
Nginx is a high-performance HTTP server and reverse proxy. It serves as the gateway for all web traffic entering the VPS. This script installs Nginx and applies a hardened security configuration.

## Dependencies
*   **None**.

## Installation Process

### 1. Package Installation
*   Installs `nginx` from the official repositories.

### 2. Security Hardening
The script copies two configuration snippets from the repository to `/etc/nginx/snippets/`:
1.  `security.conf`:
    *   Hides Nginx version info (`server_tokens off`).
    *   Sets security headers (X-Frame-Options, X-Content-Type-Options, etc.).
    *   Configures strict timeouts to prevent Slowloris attacks.
2.  `general.conf`:
    *   Configures Gzip compression.
    *   Sets caching headers for static assets.
    *   Configures file upload limits.

### 3. Firewall Configuration
*   Opens TCP port **80** (HTTP).
*   Opens TCP port **443** (HTTPS).

### 4. Service Management
*   Enables Nginx to start on boot.
*   Restarts the service to apply changes.

## Usage
Configuration files are located in `/etc/nginx/`.
To use the hardened configs, include them in your server blocks:
```nginx
server {
    listen 80;
    server_name example.com;
    
    include /etc/nginx/snippets/general.conf;
    include /etc/nginx/snippets/security.conf;
    
    location / {
        proxy_pass http://localhost:3000;
    }
}
```
