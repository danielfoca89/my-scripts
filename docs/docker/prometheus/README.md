# Prometheus

**Category**: Docker
**Script Path**: `apps/docker/prometheus/install.sh`

## Description
Prometheus is an open-source systems monitoring and alerting toolkit. This script installs Prometheus along with **Node Exporter** to collect hardware and OS metrics from the host.

## Dependencies
*   **Docker Engine**: Required.

## Installation Process

### 1. Network Setup
*   Creates a dedicated network: `monitoring_net`. This isolates monitoring traffic from the main application network (`vps_network`), although they can be bridged if needed.

### 2. Directory Setup
*   **Base Directory**: `/opt/monitoring/prometheus`
*   **Data Directory**: `/opt/monitoring/prometheus/data`
*   **Config Directory**: `/opt/monitoring/prometheus/config`

### 3. Configuration Generation
Generates a `prometheus.yml` file in the config directory with two scrape jobs:
1.  `node_exporter`: Scrapes metrics from the Node Exporter container.
2.  `prometheus`: Scrapes internal metrics from itself.

### 4. Container Deployment (Prometheus)
Deploys `prom/prometheus:latest` with:
*   **Container Name**: `prometheus`
*   **Network**: `monitoring_net`
*   **Volume Mounts**:
    *   Config file mapped to `/etc/prometheus/prometheus.yml`.
    *   Data directory mapped to `/prometheus`.

### 5. Container Deployment (Node Exporter)
Deploys `prom/node-exporter:latest` with:
*   **Container Name**: `node-exporter`
*   **Network**: `monitoring_net`
*   **Function**: Exposes host metrics (CPU, RAM, Disk) on port 9100 (internal to the network).

## Usage
*   **Dashboard URL**: `http://<VPS_IP>:9090` (Note: The script does NOT explicitly open port 9090 in the firewall, implying it is intended for internal use or access via reverse proxy/tunnel).
