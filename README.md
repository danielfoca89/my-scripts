# VPS Enterprise Orchestrator

**Automated, modular, and security-focused infrastructure provisioning.**

This repository contains a comprehensive **Infrastructure as Code (IaC)** solution based on **GitHub Actions** and **Modular Bash Scripts**. It is designed to transform a fresh, empty VPS into a hardened Enterprise-grade production server, followed by the controlled installation of modern applications.

> **Author:** Daniel Foca  
> **License:** MIT

---

## Hybrid Architecture Strategy

The system employs a **Hybrid Deployment Strategy** to balance performance, security, and manageability:

1.  **Host Layer (Bare Metal):** Critical infrastructure components that require direct kernel access or manage the system itself run directly on the host OS. This ensures maximum performance and tighter system integration.
    *   *Examples:* Nginx (Gateway), WireGuard (VPN), Docker Engine.

2.  **Container Layer (Docker):** Applications, databases, and automation tools run in isolated Docker containers. They communicate via a dedicated internal network (`vps_network`), keeping the host OS clean and dependency-free.
    *   *Examples:* MariaDB, PostgreSQL, n8n, Grafana, Uptime Kuma.

---

## Documentation

### 🚀 Workflows (CI/CD)
*   [VPS Enterprise Hardening](docs/workflows/vps-enterprise-base/README.md) - The bootstrap process.
*   [Install & Secure Applications](docs/workflows/install-apps/README.md) - The app deployer.

### 🐳 Docker Applications
*   [Arcane (AI)](docs/docker/arcane/README.md)
*   [Docker Engine](docs/docker/engine/README.md)
*   [Grafana](docs/docker/grafana/README.md)
*   [MariaDB](docs/docker/mariadb/README.md)
*   [MongoDB](docs/docker/mongodb/README.md)
*   [n8n Automation](docs/docker/n8n/README.md)
*   [Netdata](docs/docker/netdata/README.md)
*   [Portainer](docs/docker/portainer/README.md)
*   [PostgreSQL](docs/docker/postgres/README.md)
*   [Prometheus](docs/docker/prometheus/README.md)
*   [Redis](docs/docker/redis/README.md)
*   [Uptime Kuma](docs/docker/uptime-kuma/README.md)

### 🖥️ Host Applications
*   [Certbot SSL](docs/host/certbot/README.md)
*   [Log Maintenance](docs/host/log-maintenance/README.md)
*   [Nginx Web Server](docs/host/nginx/README.md)
*   [NodeJS Runtime](docs/host/nodejs/README.md)
*   [Security Audit](docs/host/security-audit/README.md)
*   [WireGuard VPN](docs/host/wireguard/README.md)

---

## Modular Architecture

The system is designed with strict separation of concerns. The orchestration logic (CI/CD) is decoupled from the installation logic (Bash).

### File Structure

```text
.
├── .github/workflows/
│   ├── vps-enterprise-base.yml    # Workflow 1: Hardening & Base Provisioning
│   └── install-apps.yml           # Workflow 2: Application Orchestrator
├── docs/                          # Detailed Documentation
├── lib/
│   ├── config/                    # Standard Configurations (Nginx, etc.)
│   └── utils.sh                   # Core Library (OS Detect, Sudo Wrapper, Colors)
├── apps/
│   ├── docker/                    # Containerized Applications (n8n, Postgres, etc.)
│   └── host/                      # Host-level Applications (Nginx, WireGuard, etc.)
```
