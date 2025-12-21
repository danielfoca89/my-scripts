# Netdata

**Category**: Docker (Installed on Host)
**Script Path**: `apps/docker/netdata/install.sh`

## Description
Netdata is a real-time infrastructure monitoring tool.
**Important Note**: Although this script is categorized under `docker` in the repository structure, it currently installs Netdata **directly on the Host OS** using the official kickstart script. This is often preferred for monitoring tools to ensure they have full access to system metrics (CPU, RAM, Disk I/O) without the abstraction layer of a container.

## Dependencies
*   **None**: Does not strictly require Docker, as it installs on the host.

## Installation Process

### 1. Download & Install
*   Downloads the official `kickstart.sh` script from `https://my-netdata.io/kickstart.sh`.
*   Executes it with the following flags:
    *   `--non-interactive`: Runs without user prompts.
    *   `--stable-channel`: Installs the stable release.
    *   `--disable-telemetry`: Opts out of sending anonymous usage statistics.

### 2. Firewall Configuration
*   Opens TCP port **19999** via UFW.

## Usage
*   **Dashboard URL**: `http://<VPS_IP>:19999`
*   **Features**: Real-time visualization of thousands of metrics with 1-second granularity.
