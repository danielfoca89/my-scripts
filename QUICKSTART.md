# 🚀 Quick Start Guide

## Installation (3 minutes)

### 1. Clone Repository
```bash
git clone https://github.com/danielfoca89/my-scripts.git
cd my-scripts
```

### 2. Optional: Harden VPS (Recommended for new servers)
```bash
sudo ./workflows/vps-initial-setup.sh
```
Prompts: username, password, SSH port

### 3. Launch Orchestrator
```bash
./orchestrator.sh
```

## First Applications

### Essential Stack
```
1. Infrastructure > Docker Engine  (required for all Docker apps)
2. Databases > PostgreSQL         (if needed)
3. Infrastructure > Nginx         (for web apps)
4. Infrastructure > Certbot       (for SSL)
```

### Example: Install n8n
```
Menu Navigation:
1. Install Docker Engine first
2. Install PostgreSQL 
3. Install n8n (auto-detects dependencies)
4. Credentials saved in ~/.vps-secrets/.env_n8n
```

## Commands

```bash
# Interactive menu
./orchestrator.sh

# List credentials
./orchestrator.sh --list-secrets

# Backup secrets
./orchestrator.sh --backup-secrets

# Regenerate secrets for app
./orchestrator.sh --regenerate postgres

# Help
./orchestrator.sh --help
```

## Credentials Location

All auto-generated passwords:
```bash
~/.vps-secrets/
├── .env_postgres
├── .env_mariadb
├── .env_n8n
└── ...
```

View credentials:
```bash
cat ~/.vps-secrets/.env_postgres
```

## Docker Management

```bash
# List containers
docker ps

# View logs
docker logs container_name

# Restart container
docker restart container_name

# Container shell
docker exec -it container_name bash
```

## Troubleshooting

**Docker not found?**
```bash
Install: Infrastructure > Docker Engine
Then: newgrp docker
```

**Port in use?**
```bash
sudo netstat -tulpn | grep :PORT
docker stop conflicting_container
```

**View logs?**
```bash
docker logs -f container_name
cat ~/.vps-orchestrator/logs/orchestrator_$(date +%Y%m%d).log
```

## Support

- Full docs: [README.md](README.md)
- Issues: GitHub Issues
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---
**Happy Orchestrating! 🎉**
