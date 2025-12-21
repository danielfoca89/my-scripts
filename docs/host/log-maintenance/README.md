# Log Maintenance

**Category**: Host
**Script Path**: `apps/host/log-maintenance/install.sh`

## Description
This script configures system-wide log rotation policies and installs disk usage analysis tools. It is a preventative measure to ensure the VPS does not run out of disk space due to runaway log files, which is a common issue in production environments.

## Dependencies
*   **None**.

## Installation Process

### 1. Docker Log Rotation
Creates a custom configuration file at `/etc/logrotate.d/docker-containers`.
*   **Target**: `/var/lib/docker/containers/*/*.log`
*   **Frequency**: `daily`
*   **Retention**: `rotate 7` (Keep 7 days of logs)
*   **Compression**: `compress` (Gzip old logs)
*   **Mode**: `copytruncate` (Truncates the active log file in place, ensuring Docker doesn't crash).

### 2. Tool Installation
Installs `ncdu` (NCurses Disk Usage).
*   `ncdu` is a fast, terminal-based disk usage analyzer that helps you instantly find which folders are consuming the most space.

## Usage
*   **Check Disk Usage**: Run `ncdu /` to scan the entire filesystem.
*   **Log Rotation**: Runs automatically via the system's daily cron job.
