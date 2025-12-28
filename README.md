# VPS Orchestrator

> Production-ready VPS management system with **automatic dependency resolution**, **health monitoring**, **audit logging**, and **security-first** deployment of 20+ applications

## Quick Start

```bash
# Clone the repository
git clone https://github.com/danielfoca89/my-scripts.git
cd my-scripts

# Run the orchestrator
./orchestrator.sh

# Select application number and press Enter
# Example: Type "12" for n8n, dependencies auto-install
```

## How It Works

1. **Run orchestrator**: `./orchestrator.sh`
2. **See all 20 applications** with status:
   - `1) n8n                       [✓ Installed]` - shows what's already installed
   - `2) mariadb` - not installed yet
3. **Type the number** of the app you want (works with or without sudo)
4. **Dependencies auto-install** - Docker, PostgreSQL, Nginx, etc.
5. **Domain & SSL auto-configured** - for apps that need it (n8n, Grafana, etc.)
6. **Credentials auto-generated** and saved to `~/.vps-secrets/`

**That's it!** Intelligent dependency management, zero manual setup, universal OS support.

## Available Applications (20)

### Infrastructure (5)
- **Docker Engine** - Container runtime (auto-installed as dependency)
- **Nginx** - Native reverse proxy & web server (auto-configured for SSL)
- **Portainer** - Docker management UI
- **Certbot** - Native SSL certificate automation (Let's Encrypt)
- **Arcane** - Modern Docker management UI

### Databases (4)
- **PostgreSQL** - Shared database service (each app creates own DB/user)
- **MariaDB** - MySQL-compatible database
- **MongoDB** - NoSQL document database
- **Redis** - Native in-memory cache & data store

### Monitoring (4)
- Grafana - Analytics & visualization dashboards
- Prometheus - Metrics collection & alerting
- Netdata - Real-time system monitoring
- Uptime Kuma - Uptime monitoring & status pages

### Automation (1)
- **n8n** - Workflow automation with auto SSL setup (domain + certificate + reverse proxy)

### Security (3)
- **WireGuard** - Native VPN solution (kernel module)
- **Fail2ban** - Intrusion prevention system
- **Security Audit** - Vulnerability scanning tools

### System (3)
- VPS Setup - Complete server hardening workflow
- Node.js - JavaScript runtime (via NVM)
- Log Maintenance - Automated log rotation & cleanup

## Universal OS Support

**Works on any major Linux distribution:**
- 🐧 **Debian/Ubuntu** - Debian 11+, Ubuntu 20.04+, Linux Mint, Pop!_OS
- 🎩 **RHEL/CentOS** - AlmaLinux 8+, Rocky Linux 8+, CentOS 8+, Fedora 36+
- ⚡ **Arch Linux** - Arch, Manjaro

**Auto-adapts to your system:**
```bash
# Automatically detects and uses:
- Package Manager: apt/apt-get / dnf / yum / pacman
- Sudo Groups: sudo (Debian/Ubuntu) / wheel (RHEL/AlmaLinux)
- SSH Service: ssh (Debian) or sshd (RHEL)
- Firewall: ufw (Debian) or firewalld (RHEL)
- Log Paths: /var/log/auth.log or /var/log/secure
- Init System: systemd (universal)
```

**Universal sudo support:**
- ✅ **Installs sudo automatically** - setup-vps ensures sudo is installed on all distributions
- ✅ **Correct group detection** - uses `sudo` group on Debian/Ubuntu, `wheel` on RHEL/AlmaLinux
- ✅ **run_sudo() wrapper** - all scripts use universal sudo function that works as root or non-root
- ✅ **Works everywhere** - SUDO_PASS environment variable, interactive prompts, or direct execution

## Production Features

### 🔍 Audit Logging System
- **Comprehensive logging** - All installations, updates, backups tracked
- **Secure storage** - `~/.vps-secrets/.audit.log` (chmod 600)
- **Structured format** - `[TIMESTAMP] ACTION APP_NAME by USER - DETAILS - RESULT`
- **Events tracked**:
  - Installation start/complete
  - Database creation
  - Credential backups
  - Database backups
  - VPS setup lifecycle
  - Container updates

**View audit log:**
```bash
cat ~/.vps-secrets/.audit.log
tail -f ~/.vps-secrets/.audit.log  # Live monitoring
```

### ⚡ Pre-flight Checks
- **Resource validation** before installation
- **Checks**: Disk space, RAM availability, port conflicts
- **Interactive prompts** - User confirmation before proceeding
- **Prevents failures** - Catches issues before installation starts

**Integrated in:**
- n8n: 10GB disk, 2GB RAM, port 5678
- PostgreSQL: 15GB disk, 2GB RAM, port 5432
- Docker Engine: 20GB disk, 4GB RAM

### 🛡️ Docker Resource Limits
- **Database containers** protected from resource exhaustion
- **Limits applied**:
  - PostgreSQL: 2 CPU cores, 2GB RAM (512MB guaranteed)
  - MariaDB: 2 CPU cores, 2GB RAM (512MB guaranteed)
  - MongoDB: 2 CPU cores, 2GB RAM (512MB guaranteed)
- **Benefits**: Prevents OOM, protects other services, stable performance

### 🔐 SSL Certificate Monitoring
- **Certbot timer status** - Active/inactive monitoring
- **Expiry tracking** - Days remaining calculation
- **Status levels**: 
  - OK: >30 days
  - WARNING: <30 days
  - CRITICAL: <7 days
- **Auto-renewal verification** - Alerts if certbot timer is disabled

### 📊 Web Dashboard
- **Nginx integrated** - Auto-configured during Nginx installation
- **Basic Auth** - Username/password protection
- **Visual monitoring** - Progress bars, status badges, color-coded alerts
- **Auto-updates** - Cron job updates every 2 minutes
- **Mobile responsive** - Works on all devices

### 🚀 Smart Dependency Management
- **AutomaALL apps with status** - `[✓ Installed]` marker for installed apps
- **Clear dependency feedback** - `✓ Dependency already installed: docker-engine`
- **Recursive dependency checking** - installs full dependency chain
- **No interruptions** - smooth flow without logout prompts or warnings etc.
- **Shows installed apps** with ✓ indicator
- **Recursive dependency checking** - installs full dependency chain

### 🔐 Automatic SSL & Domain Setup
- **Domain prompts** - for apps like n8n, Grafana (requires_domain=yes)
- **SSL certificate automation** - Let's Encrypt via Certbot
- **Nginx reverse proxy** - auto-configured with security headers
- **HTTPS enforcement** - HTTP → HTTPS redirect

### 💾 PostgreSQL Shared Service
- **Single PostgreSQL instance** - serves all apps with random credentials
- **Isolated databases** - each app gets own DB/user/password
- **Random database names** - `db_a3k9m2x7p5q1` (security by obscurity)
- **Random usernames** - `user_x8n4k2m9p7q5` (prevents predictable attacks)
- **Random PostgreSQL superuser** - `user_x8n4k2m9p7q5` (no default "postgres" user)
- **Credentials saved** - `~/.vps-secrets/.env_<app>` format
- **Example**: n8n creates random DB name + random user automatically
- **Note**: README examples use `n8n_db`/`n8n_user` for clarity, actual names are random
Universal sudo support** - works on all distributions
- **Automatic sudo installation** - setup-vps installs sudo if missing
- **Correct permissions** - users added to `sudo` (Debian) or `wheel` (RHEL)
- **
### 🛡️ Production Security
- **Auto-generated credentials** (32-64 character passwords)
- **Encrypted storage** in `~/.vps-secrets/` (600 permissions)
- **Password-only SSH** with su - for root access
- **Firewall configuration** (UFW/firewalld)
- **Native installations** for critical services (Nginx, Redis, Certbot, WireGuard)

## Repository Structure

```
my-scripts/
├── orchestrator.sh                    # Smart orchestrator with dependency resolution
│
├── lib/                               # Core libraries (5 modules)
│   ├── utils.sh                      # Logging, audit system, helpers
│   ├── secrets.sh                    # Credential management & encryption
│   ├── docker.sh                     # Docker operations
│   ├── os-detect.sh                  # Universal OS detection & abstraction
│   └── preflight.sh                  # Pre-installation resource checks
│
├── apps/                              # Application installers (20+)
│   ├── infrastructure/               # Core infrastructure
│   │   ├── docker-engine/           # Container runtime
│   │   ├── nginx/                   # Reverse proxy (native) + dashboard setup
│   │   ├── portainer/               # Docker management UI
│   │   ├── certbot/                 # SSL automation (native)
│   │   └── arcane/                  # Modern Docker UI
│   │
│   ├── databases/                    # Database services
│   │   ├── postgres/                # PostgreSQL (with resource limits)
│   │   ├── mariadb/                 # MariaDB (with resource limits)
│   │   ├── mongodb/                 # MongoDB (with resource limits)
│   │   └── redis/                   # Redis cache (native)
│   │
│   ├── monitoring/                   # Monitoring & observability
│   │   ├── grafana/                 # Visualization dashboards
│   │   ├── prometheus/              # Metrics collection
│   │   ├── netdata/                 # Real-time monitoring
│   │   └── uptime-kuma/             # Uptime monitoring
│   │
│   ├── automation/                   # Workflow automation
│   │   └── n8n/                     # Workflow engine with SSL
│   │
│   ├── security/                     # Security tools
│   │   ├── wireguard/               # VPN (native, kernel module)
│   │   ├── fail2ban/                # Intrusion prevention
│   │   └── security-audit/          # Vulnerability scanning
│   │
│   └── system/                       # System utilities
│       ├── setup-vps/               # Server hardening workflow
│       ├── nodejs/                  # Node.js via NVM
│       └── log-maintenance/         # Log rotation & cleanup
│
├── tools/                             # Management & monitoring tools
│   ├── health-check.sh               # System status & HTML dashboard
│   ├── setup-dashboard.sh            # Dashboard setup with Nginx Basic Auth
│   ├── backup-credentials.sh         # Credentials backup & restore
│   ├── backup-databases.sh           # Database backup & restore
│   └── update.sh                     # Container update manager
│
├── workflows/                         # Multi-step workflows
│   ├── install-apps.yml              # Batch application installation
│   └── vps-enterprise-base.yml       # Enterprise VPS setup
│
├── config/                            # Configuration files
│   ├── apps.conf                     # Application metadata + dependencies
│   └── categories.conf               # Category definitions
│
├── templates/                         # Docker Compose templates
│
└── yml-host/                          # Docker Compose files & configs
    ├── *.yml                         # Official compose files
    └── nginx/                        # Nginx site configurations

* = Native installation (not Docker)
```

## Architecture Decisions

### Native vs Docker

**Native installations** (direct on host):
- ✅ **Nginx** - Needs system-level access for port 80/443
- ✅ **Redis** - Better performance without containerization
- ✅ **Certbot** - Needs direct filesystem access for SSL certificates
- ✅ **WireGuard** - Requires kernel module for VPN tunneling

**Docker installations** (containerized):
- 🐳 **Databases** - PostgreSQL, MariaDB, MongoDB
- 🐳 **Monitoring** - Grafana, Prometheus, Netdata
- Example: n8n Installation Workflow

What happens when you select n8n:

```bash
./orchestrator.sh
# Select: 12 (n8n)

# Orchestrator checks dependencies:
✓ docker-engine not installed → auto-installs
✓ postgres not installed → auto-installs (shared service)
✓ nginx already installed → skips
✓ certbot already installed → skips

# n8n installer starts:
? Enter your domain name: domain.com or n8n.domain.com
? Enter your email for SSL: admin@domain.com

# Auto-configuration:
✓ Creates PostgreSQL database: n8n_a3k9m2x7 (random)
✓ Creates PostgreSQL user: user_x8n4k2m9 (random)
✓ Saves credentials: ~/.vps-secrets/.env_n8n
✓ Configures Nginx reverse proxy
✓ Requests SSL certificate from Let's Encrypt
✓ Updates n8n config with HTTPS settings
✓ Deploys n8n container
✓ Access: https://domain.com or https://n8n.domain.com 

# Note: DB names and users are randomly generated for security
# This example shows the format, not actual names 
```

## Credential Management

All credentials are automatically generated and securely stored:

```bash
# View credentials for an app
cat ~/.vps-secrets/.env_n8n
cat ~/.vps-secrets/.env_postgres
cat ~/.vps-secrets/.env_grafana

# Example n8n credentials (actual DB names are random):
N8N_DOMAIN='domain.com'
N8N_EMAIL='admin@domain.com'
N8N_USER='admin@n8n.local'
N8N_PASSWORD='<auto-generated-64-chars>'
N8N_DB_NAME='n8n_a3k9m2x7'  # Random generated (example shown)
N8N_DB_USER='user_x8n4k2m9'  # Random generated (example shown)
N8N_DB_PASSWORD='<auto-generated-32-chars>'

# List all stored credentials
ls -la ~/.vps-secrets/

# Note: Database names and usernames are randomly generated for security
# Examples in this README use n8n_db/n8n_user for clarity only
```

## Direct Installation (Alternative)

You can also run installers directly without the orchestrator:

```bash
# Install Docker Engine
./apps/infrastructure/docker-engine/install.sh

# Install PostgreSQL
./apps/databases/postgres/install.sh

# Run VPS hardening workflow
./apps/system/setup-vps/install.sh
```

## Statistics

- **6,500+ lines** of production bash code
- **20+ applications** fully implemented and tested
- **5 core libraries** (utils, secrets, docker, os-detect, preflight)
- **5 management tools** (health-check, dashboard, backup x2, update)
- **Universal OS support** - Debian, Ubuntu, AlmaLinux, Rocky, Fedora, CentOS
- **Universal sudo** - auto-installs and configures sudo/wheel groups
- **Smart dependency resolution** - recursive auto-install with status tracking
- **Random database credentials** - security through unpredictability
- **4 native installers** (Nginx, Redis, Certbot, WireGuard)
- **Automatic SSL** configuration for domain-based apps
- **PostgreSQL shared service** with isolated databases per app
- **Docker resource limits** for databases (CPU + RAM)
- **Audit logging system** for compliance and troubleshooting
- **Pre-flight checks** prevent installation failures
- **Container update manager** with safe rollback capability
- **SSL monitoring** with expiry alerts
- **Web dashboard** with Nginx Basic Auth
- **Consistent UX** - all apps show `✓` for success, clear messaging
- **Zero placeholders** - 100% functional
- **100% syntax validated** ✅
- **50+ production features** - December 2025 release

## Security Best Practices

✅ **Auto-generated strong passwords** (32-64 chars)  
✅ **Random database names** - `db_a3k9m2x7p5q1` (PostgreSQL, MariaDB, MongoDB, n8n)  
✅ **Random usernames** - `user_x8n4k2m9p7q5` (all databases + Grafana admin)  
✅ **No default credentials** - PostgreSQL, Grafana use random usernames  
✅ **Encrypted credential storage** (`~/.vps-secrets/` with 600/700 permissions)  
✅ **Audit logging** - All critical operations tracked in `~/.vps-secrets/.audit.log`  
✅ **Resource limits** - Database containers protected from resource exhaustion  
✅ **Pre-flight checks** - Validation before installation prevents failures  
✅ **Universal sudo support** (auto-installs, correct groups)  
✅ **Password-based SSH** with `su -` for root access  
✅ **Universal firewall support** (UFW/firewalld auto-detected)  
✅ **Docker network isolation** (vps_network)  
✅ **Fail2ban intrusion prevention**  
✅ **Regular security audits** via Trivy  
✅ **SSL/TLS certificate automation** (Let's Encrypt)  
✅ **HTTPS enforcement** with Nginx reverse proxy  
✅ **Database isolation** (each app has own DB/user)  
✅ **Native installations** for critical services  
✅ **Dashboard Basic Auth** - Protected web monitoring  
✅ **SSL expiry monitoring** - Automatic certificate tracking  
✅ **All privileged commands** use `run_sudo` wrapper

## Management Tools

### Health Check & Dashboard

Monitor all services with terminal output or web dashboard:

```bash
# Terminal output
./tools/health-check.sh

# Generate HTML dashboard
sudo ./tools/health-check.sh --html /var/www/html/status.html
```

**Web Dashboard Features:**
- 🔒 **Basic Auth protected** (auto-configured with Nginx)
- 📊 **Real-time stats** - CPU, RAM, Disk with visual progress bars
- 🐳 **Container status** - Running/stopped with health checks
- 🔐 **SSL monitoring** - Certificate expiry with WARNING/CRITICAL alerts
- 💾 **Backup status** - Credentials and database backup counts
- 🔄 **Auto-refresh** - Browser: 30 sec, Server cron: 2 min
- 🎨 **Modern UI** - Responsive design with gradient colors

**Dashboard Setup** (automatically runs with Nginx installer):
```bash
# Manual setup
sudo ./tools/setup-dashboard.sh

# Access dashboard
# URL: http://your-ip/status.html
# Credentials: ~/.vps-secrets/.env_dashboard
```

**Dashboard output includes:**
- System resources (disk, memory, CPU) with color-coded progress bars
- Docker containers (status, health)
- Native services (nginx, redis, fail2ban)
- Network ports
- Credentials count
- SSL certificates expiry (with days remaining)
- Backup status (credentials + databases)

### Container Update Manager

Update Docker containers safely with preserved data:

```bash
# List all containers
./tools/update.sh list

# Update single container
./tools/update.sh update <container-name>
# Examples:
./tools/update.sh update n8n
./tools/update.sh update postgres

# Update all containers
./tools/update.sh update-all
```

**Features:**
- ✅ Uses docker-compose.yml when available
- ✅ Preserves volumes and credentials
- ✅ Verifies health after update
- ✅ Audit logging for all updates
- ✅ Safe pull → stop → remove → recreate workflow

**Supported containers:**
n8n, postgres, mariadb, mongodb, grafana, prometheus, portainer, arcane, redis, netdata, uptime-kuma

### Backup Credentials

Backup all application credentials from `~/.vps-secrets`:

```bash
# Create backup
./tools/backup-credentials.sh backup

# List all backups
./tools/backup-credentials.sh list

# Restore from backup
./tools/backup-credentials.sh restore credentials_20251228_103045.tar.gz

# Cleanup old backups (30+ days)
./tools/backup-credentials.sh cleanup

# Set custom retention
RETENTION_DAYS=14 ./tools/backup-credentials.sh backup
```

Backups stored in: `~/.vps-secrets/.backup/`

### Backup Databases

Backup PostgreSQL, MariaDB, and MongoDB databases:

```bash
# Backup all databases
./tools/backup-databases.sh

# Backup specific database
./tools/backup-databases.sh postgres
./tools/backup-databases.sh mariadb
./tools/backup-databases.sh mongodb

# List all backups
./tools/backup-databases.sh list

# Cleanup old backups (7+ days)
./tools/backup-databases.sh cleanup

# Set custom retention
RETENTION_DAYS=14 ./tools/backup-databases.sh
```

Backups stored in: `/opt/backups/{postgres,mariadb,mongodb}/`

### Automated Backups (Cron)

Setup daily automated backups:

```bash
# Add to crontab
crontab -e

# Credentials backup daily at 2 AM
0 2 * * * /path/to/my-scripts/tools/backup-credentials.sh backup

# Database backup daily at 3 AM
0 3 * * * /path/to/my-scripts/tools/backup-databases.sh all

# Dashboard update every 2 minutes (auto-configured by setup-dashboard.sh)
*/2 * * * * /path/to/my-scripts/tools/health-check.sh --html /var/www/html/status.html
```

## Quick Reference

### View Credentials
```bash
# List all credentials
ls -la ~/.vps-secrets/

# View specific app credentials
cat ~/.vps-secrets/.env_n8n
cat ~/.vps-secrets/.env_postgres
cat ~/.vps-secrets/.env_dashboard

# View audit log
tail -f ~/.vps-secrets/.audit.log
```

### Container Management
```bash
# List containers
docker ps -a

# Update container
./tools/update.sh update n8n

# View logs
docker logs n8n -f

# Restart container
docker restart n8n
```

### Dashboard Access
```bash
# View dashboard credentials
cat ~/.vps-secrets/.env_dashboard

# Manual dashboard update
sudo ./tools/health-check.sh --html

# Access URL: http://your-ip/status.html
```

### System Status
```bash
# Health check
./tools/health-check.sh

# Check SSL certificates
certbot certificates

# View Nginx status
sudo systemctl status nginx

# View Docker status
sudo systemctl status docker
```

## Troubleshooting

### Permissions Issue
```bash
chmod +x orchestrator.sh
chmod +x apps/**/*/install.sh
```

### View Application Logs
```bash
docker logs <container-name> -f
```

### Check Container Status
```bash
docker ps -a
```

## License

MIT License - Copyright (c) 2025 Daniel Foca

See [LICENCE](LICENCE) file for full license text.

## Author

**Daniel Foca** ([@danielfoca89](https://github.com/danielfoca89))
