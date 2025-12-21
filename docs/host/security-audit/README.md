# Security Audit Tools

**Category**: Host
**Script Path**: `apps/host/security-audit/install.sh`

## Description
Installs a suite of security auditing and scanning tools to monitor the health and integrity of the server. These tools are essential for detecting intrusions, rootkits, and malware.

## Dependencies
*   **None**.

## Installation Process

### 1. Tool Installation
Installs the following packages:
*   `lynis`: A battle-tested security auditing tool for Unix-based systems. It scans the system configuration and reports security weaknesses.
*   `rkhunter` (Rootkit Hunter): Scans for rootkits, backdoors, and possible local exploits.
*   `clamav`: An open-source antivirus engine for detecting trojans, viruses, malware & other malicious threats.
*   `clamav-daemon`: The background service for ClamAV.

### 2. Configuration & Updates
*   **ClamAV**: Stops the service, runs `freshclam` to download the latest virus definitions, and restarts the service.
*   **RKHunter**: Runs `--propupd` (Property Update). This tells RKHunter to record the current file properties (hash, size, permissions) of system binaries as the "known good" state. Future scans will alert if these files change.

## Usage
*   **Audit System**: `sudo lynis audit system`
*   **Check Rootkits**: `sudo rkhunter --check`
*   **Scan Directory**: `sudo clamscan -r /home`
