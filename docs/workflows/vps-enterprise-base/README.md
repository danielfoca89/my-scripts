# VPS Enterprise Hardening Workflow

**File Path**: `.github/workflows/vps-enterprise-base.yml`

## Description
This is the **bootstrap workflow**. It takes a fresh, insecure VPS (provided by a cloud provider like DigitalOcean, Hetzner, or AWS) and transforms it into a hardened, enterprise-grade server in a single run. It handles user creation, SSH hardening, firewall setup, and fail2ban configuration.

## Inputs
| Input | Description | Required | Default |
| :--- | :--- | :--- | :--- |
| `vps_ip` | The Public IP address of the fresh VPS. | Yes | - |
| `root_user` | The initial root username (usually `root`). | Yes | `root` |
| `root_password` | The initial root password (emailed by provider). | Yes | - |
| `new_username` | The new sudo-enabled admin user to create. | Yes | - |
| `new_password` | The password for the new admin user. | Yes | - |
| `new_ssh_port` | The custom port to move SSH to (Security through obscurity). | Yes | `2222` |

## Execution Flow

### Phase 1: Pre-Flight & System Prep
1.  **Connection Check**: Verifies SSH connectivity using the provided root credentials.
2.  **Lock Wait**: Checks for any background `apt` processes (common on fresh Ubuntu installs) and waits for them to finish to avoid lock errors.
3.  **Timezone**: Sets the system timezone to `UTC` (Standard for servers).
4.  **Update & Upgrade**: Runs `apt-get update` and `apt-get upgrade` to patch all packages.
5.  **Tool Installation**: Installs essential tools: `ufw`, `fail2ban`, `auditd`, `chrony`, `curl`, `htop`.

### Phase 2: Identity Management
1.  **User Creation**: Creates the `new_username` with a home directory and bash shell.
2.  **Sudo Access**: Adds the new user to the `sudo` group.
3.  **Key Injection**: Generates a temporary SSH key pair in the runner and injects the public key into the new user's `authorized_keys`.

### Phase 3: SSH Hardening
Modifies `/etc/ssh/sshd_config` to apply strict security policies:
*   **Port**: Changes default port 22 to `new_ssh_port`.
*   **Root Login**: `PermitRootLogin no` (Disables root login completely).
*   **Password Auth**: `PasswordAuthentication no` (Forces Key-based auth).
*   **Empty Passwords**: `PermitEmptyPasswords no`.
*   **Max Tries**: `MaxAuthTries 3`.

### Phase 4: Network Security (Firewall)
Configures UFW (Uncomplicated Firewall):
*   **Default Policy**: Deny Incoming, Allow Outgoing.
*   **SSH**: Allows traffic on `new_ssh_port`.
*   **Web**: Allows ports 80 (HTTP) and 443 (HTTPS).
*   **Enable**: Activates the firewall.

### Phase 5: Intrusion Prevention (Fail2Ban)
Configures Fail2Ban to monitor logs and ban IPs that show malicious behavior:
*   **Jail**: `sshd`
*   **Port**: Monitors the custom `new_ssh_port`.
*   **Max Retry**: Bans after 3 failed attempts.
*   **Find Time**: Look back window of 10 minutes.
*   **Ban Time**: 1 hour ban duration.

## Outcome
After this workflow completes, the VPS is secured. You can no longer log in as `root`. You must log in as the `new_username` on the `new_ssh_port` using the SSH key or password (if password auth was kept enabled for the user, though the script disables it globally).
