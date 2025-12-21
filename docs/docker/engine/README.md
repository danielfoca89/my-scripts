# Docker Engine

**Category**: Docker
**Script Path**: `apps/docker/engine/install.sh`

## Description
This is the foundational script for the entire containerized ecosystem. It installs the Docker Community Edition (CE) runtime, the Docker CLI, and the Docker Compose plugin. It also performs security hardening on the Docker Daemon.

## Dependencies
*   **None**: This is a base dependency itself.

## Installation Process

### 1. OS Detection & Repository Setup
*   Detects the operating system (Ubuntu, Debian, CentOS, etc.).
*   Installs necessary prerequisites (`ca-certificates`, `curl`, `gnupg`).
*   **Keyring**: Downloads the official Docker GPG key to `/etc/apt/keyrings/docker.gpg`.
*   **Repository**: Adds the stable Docker repository to `/etc/apt/sources.list.d/docker.list`.

### 2. Package Installation
Installs the following packages:
*   `docker-ce`: The Docker Daemon.
*   `docker-ce-cli`: The Command Line Interface.
*   `containerd.io`: The container runtime.
*   `docker-buildx-plugin`: Extended build capabilities.
*   `docker-compose-plugin`: Native `docker compose` support.

### 3. Security & Hardening
*   **Service Enablement**: Enables and starts the `docker` systemd service.
*   **User Groups**: Adds the current user to the `docker` group to allow running commands without `sudo`.
*   **Log Rotation**: Configures the Docker Daemon (`/etc/docker/daemon.json`) to limit log file sizes. This prevents Docker containers from filling up the disk with logs.
    *   `max-size`: "10m"
    *   `max-file`: "3"

## Usage
This script is typically invoked automatically by other scripts using `require_dependency "docker/engine"`.
To verify installation:
```bash
docker --version
docker run hello-world
```
