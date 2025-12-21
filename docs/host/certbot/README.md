# Certbot SSL

**Category**: Host
**Script Path**: `apps/host/certbot/install.sh`

## Description
Certbot is a free, open source software tool for automatically using Let's Encrypt certificates on manually-administrated websites to enable HTTPS. This script installs Certbot and the Nginx plugin.

## Dependencies
*   **None**: Installs directly on the host.

## Installation Process

### 1. Package Installation
*   Detects the OS (APT/YUM).
*   Installs `certbot` and `python3-certbot-nginx`.

### 2. Verification
*   Runs `certbot renew --dry-run`. This is a critical step that verifies:
    1.  Certbot can communicate with Let's Encrypt servers.
    2.  The automated renewal system (systemd timer/cron) is functioning correctly.

## Usage
To secure a domain configured in Nginx:
```bash
sudo certbot --nginx -d yourdomain.com
```
Certbot will automatically modify your Nginx configuration to serve HTTPS and redirect HTTP traffic.
