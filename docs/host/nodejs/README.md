# NodeJS Runtime

**Category**: Host
**Script Path**: `apps/host/nodejs/install.sh`

## Description
Installs the Node.js JavaScript runtime environment and the PM2 process manager. It sets up the environment for running modern JavaScript applications directly on the host (outside of Docker).

## Dependencies
*   **None**.

## Installation Process

### 1. Repository Setup
*   Adds the **NodeSource** repository to get the latest LTS version (currently Node 20.x).
*   Standard Ubuntu repositories often have very old versions of Node.js, so this step is crucial.

### 2. Package Installation
*   Installs `nodejs`.
*   Installs `build-essential` (GCC, Make) to allow compiling native add-ons (required by some npm packages).

### 3. Process Manager (PM2)
*   Installs `pm2` globally via npm (`npm install -g pm2`).
*   PM2 is a production process manager that keeps apps alive forever and reloads them without downtime.

### 4. Startup Configuration
*   Runs `pm2 startup` to generate and execute a systemd startup script.
*   This ensures that all PM2-managed applications restart automatically if the VPS reboots.

## Usage
*   **Start an App**: `pm2 start app.js --name "my-app"`
*   **Save State**: `pm2 save` (Freezes the process list for reboot)
*   **Monitor**: `pm2 monit`
