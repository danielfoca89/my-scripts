# Docker Engine

High-performance container runtime platform.

## Features
- Container orchestration
- Image management
- Network isolation
- Volume management

## Installation
Automatically installs:
- Docker Engine (latest stable)
- Docker Compose plugin
- Default network: vps_network
- Optimized daemon configuration

## Post-Installation
After installation, you may need to:
1. Logout and login again (for docker group)
2. Or run: `newgrp docker`

## Usage
```bash
# Run a container
docker run -d --name myapp --network vps_network myimage

# Using Docker Compose
docker compose up -d

# Check running containers
docker ps

# View logs
docker logs myapp
```

## Management
- Start: `systemctl start docker`
- Stop: `systemctl stop docker`
- Status: `systemctl status docker`
- Logs: `journalctl -u docker`
