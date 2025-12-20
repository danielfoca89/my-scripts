# VPS Enterprise Orchestrator

**Automated, modular, and security-focused infrastructure provisioning.**

This repository contains a comprehensive **Infrastructure as Code (IaC)** solution based on **GitHub Actions** and **Modular Bash Scripts**. It is designed to transform a fresh, empty VPS into a hardened Enterprise-grade production server, followed by the controlled installation of modern applications.

> **Author:** Daniel Foca  
> **License:** MIT

---

## Hybrid Architecture Strategy

The system employs a **Hybrid Deployment Strategy** to balance performance, security, and manageability:

1.  **Host Layer (Bare Metal):** Critical infrastructure components that require direct kernel access or manage the system itself run directly on the host OS. This ensures maximum performance and tighter system integration.
    *   *Examples:* Nginx (Gateway), WireGuard (VPN), Cockpit (SysAdmin), Docker Engine.

2.  **Container Layer (Docker):** Applications, databases, and automation tools run in isolated Docker containers. They communicate via a dedicated internal network (`vps_network`), keeping the host OS clean and dependency-free.
    *   *Examples:* MariaDB, PostgreSQL, n8n, Grafana, Uptime Kuma.

---

## Modular Architecture

The system is designed with strict separation of concerns. The orchestration logic (CI/CD) is decoupled from the installation logic (Bash).

### File Structure

```text
.
├── .github/workflows/
│   ├── vps-enterprise-base.yml    # Workflow 1: Hardening & Base Provisioning
│   └── install-apps.yml           # Workflow 2: Application Orchestrator
├── lib/
│   ├── config/                    # Standard Configurations (Nginx, etc.)
│   └── utils.sh                   # Core Library (OS Detect, Sudo Wrapper, Colors)
└── apps/
    ├── infrastructure/
    │   ├── docker.sh              # Docker Engine (Host)
    │   ├── arcane.sh              # Infrastructure Manager (Docker)
    │   ├── cockpit.sh             # System Web Console (Host)
    │   ├── nodejs.sh              # Node.js Runtime (Host)
    │   └── portainer.sh           # Docker UI (Docker)
    ├── web/
    │   ├── nginx.sh               # Web Server Gateway (Host)
    │   ├── certbot.sh             # SSL Automation (Host)
    │   └── uptime-kuma.sh         # Status Monitor (Docker)
    ├── database/
    │   ├── redis.sh               # Redis (Docker)
    │   ├── postgresql.sh          # PostgreSQL (Docker)
    │   ├── mysql.sh               # MySQL (Docker)
    │   ├── mariadb.sh             # MariaDB (Docker)
    │   └── mongodb.sh             # MongoDB (Docker)
    ├── automation/
    │   └── n8n.sh                 # Workflow Automation (Docker - Connects to Postgres)
    ├── monitoring/
    │   ├── netdata.sh             # Real-time monitoring (Host)
    │   ├── prometheus.sh          # Metrics Collector (Docker)
    │   └── grafana.sh             # Dashboard (Docker - Port 3100)
    └── security/
        ├── wireguard.sh           # VPN Access (Host)
        ├── restic.sh              # Backup Tool (Host)
        ├── log-maintenance.sh     # Log Rotation (Host)
        └── security-audit.sh      # Lynis, RKHunter, ClamAV (Host)
```

---

## Security "By Design"

This is not just an installer; it is a security suite. The setup enforces **Enterprise Security Benchmarks** automatically:

1.  **Least Privilege Principle:** All applications are installed and managed by a non-root user.
2.  **Strict Firewall (UFW):** The default policy is `Incoming Deny`. Ports are opened explicitly only when an application requires it.
3.  **Container Isolation:** Databases and Apps run in Docker containers on a private network (`vps_network`). They are not exposed to the public internet unless proxied via Nginx or explicitly opened.
4.  **Network Isolation:** Databases bind to the container network. Remote access is only possible via VPN (WireGuard) or SSH Tunnels.
5.  **Fail2Ban:** actively monitors the custom SSH port to block brute-force attacks.
6.  **Audit Trails:** `auditd` is configured to log changes to critical system files.

---

## Usage Guide

### Phase 1: Provisioning (One-Time Run)
Run the **`VPS Enterprise Hardening`** workflow on a fresh VPS.

**What it does:**
*   Updates the OS and detects distribution.
*   Creates a new Admin User with internal SSH keys.
*   **SSH Hardening:** Changes default port (e.g., to `2222`), disables Root Login, and enforces User Whitelisting.
*   **System Hardening:** Configures Kernel parameters, Timezone (UTC), and Audit rules.

**Inputs:** Target IP, Current Root Credentials, New User Credentials, New SSH Port.

### Phase 2: Application Deployment
Run the **`Install & Secure Applications`** workflow.

**What it does:**
*   Connects via the new Admin User.
*   Dynamically resolves the requested script from the `apps/` directory.
*   Uploads the library and executes the installation securely (Host or Docker).
*   Configures the Firewall specifically for that app.

**Inputs:** Target IP, Admin Credentials, and **Application Selection**.

---

## Application Catalog & Port Management

The system automatically manages port conflicts and firewall rules.

| Category | Application | Port | Type | Dependencies | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **System** | **SSH Custom** | `2222` | Host | None | Set during provisioning |
| **Infra** | **Arcane** | `3000` | Docker | Docker | Infrastructure Manager / PaaS |
| **Infra** | **Cockpit** | `9090` | Host | None | System Web Console |
| **Infra** | **Portainer** | `9443` | Docker | Docker | Docker UI |
| **Web** | **Nginx** | `80/443`| Host | None | Reverse Proxy Gateway |
| **Web** | **Certbot** | - | Host | Nginx | SSL Certificate Manager |
| **Monitor** | **Grafana** | `3100` | Docker | Prometheus | Dashboard (Port 3100 to avoid conflict) |
| **Monitor** | **Netdata** | `19999`| Host | None | Real-time Dashboard |
| **Monitor** | **Uptime Kuma**| `3001` | Docker | Docker | Status Page |
| **Auto** | **n8n** | `5678` | Docker | **PostgreSQL** | Workflow Automation |
| **DB** | **PostgreSQL** | `5432` | Docker | Docker | VPN/Tunnel access only |
| **DB** | **MySQL** | `3306` | Docker | Docker | VPN/Tunnel access only |
| **DB** | **MariaDB** | `3306` | Docker | Docker | VPN/Tunnel access only |
| **DB** | **MongoDB** | `27017`| Docker | Docker | VPN/Tunnel access only |
| **DB** | **Redis** | `6379` | Docker | Docker | VPN/Tunnel access only |
| **Sec** | **WireGuard** | `51820`| Host | Kernel | VPN for internal service access |

---

## 🤝 How to Contribute

To add a new application to the suite:

1.  **Create the Script:** Create `apps/category/myapp.sh`.
2.  **Import Utils:** The script must start with the dynamic source block:
    ```bash
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/../../lib/utils.sh" ]; then
        source "$SCRIPT_DIR/../../lib/utils.sh"
    elif [ -f "/tmp/apps/lib/utils.sh" ]; then
        source "/tmp/apps/lib/utils.sh"
    else
        echo "Error: utils.sh not found."
        exit 1
    fi
    ```
3.  **Use Helpers:** Use `run_sudo`, `log_info`, and `open_port` for consistency.
4.  **Register:** Add the option `"Category | myapp"` to `.github/workflows/install-apps.yml`.

---

## Disclaimer

This software is provided "as is". While it implements strict security standards, the author is not responsible for any data loss or security breaches resulting from misconfiguration or misuse of the generated infrastructure.
