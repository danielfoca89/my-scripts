#!/bin/bash

# ==============================================================================
# VPS INITIAL SETUP & HARDENING
# Universal VPS configuration for Ubuntu, Debian, AlmaLinux, etc.
# Run this LOCALLY on the VPS (not via SSH)
# ==============================================================================

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load OS detection library
if [ -f "${SCRIPT_DIR}/lib/os-detect.sh" ]; then
    source "${SCRIPT_DIR}/lib/os-detect.sh"
else
    echo "ERROR: OS detection library not found!"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}>>> $1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Banner
print_banner() {
    clear
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║             VPS INITIAL SETUP & HARDENING                     ║
║            Enterprise Security Configuration                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo ""
    log_info "Detected OS: $(get_os_info)"
    echo ""
}

# Gather user input
gather_information() {
    log_step "Configuration Input Required"
    echo ""
    
    # New username
    while true; do
        echo -ne "${YELLOW}Enter new admin username:${NC} "
        read -r NEW_USER
        
        if [ -z "$NEW_USER" ]; then
            log_error "Username cannot be empty"
            continue
        fi
        
        if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]{2,31}$ ]]; then
            log_error "Invalid username (use lowercase, 3-32 chars)"
            continue
        fi
        
        if id "$NEW_USER" &>/dev/null; then
            log_warn "User $NEW_USER already exists"
            echo -ne "${YELLOW}Use existing user? (y/n):${NC} "
            read -r choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                break
            fi
            continue
        fi
        
        break
    done
    
    # New password
    while true; do
        echo -ne "${YELLOW}Enter password for $NEW_USER:${NC} "
        read -s NEW_PASSWORD
        echo ""
        
        if [ ${#NEW_PASSWORD} -lt 8 ]; then
            log_error "Password must be at least 8 characters"
            continue
        fi
        
        echo -ne "${YELLOW}Confirm password:${NC} "
        read -s PASSWORD_CONFIRM
        echo ""
        
        if [ "$NEW_PASSWORD" != "$PASSWORD_CONFIRM" ]; then
            log_error "Passwords do not match"
            continue
        fi
        
        break
    done
    
    # SSH port
    while true; do
        echo -ne "${YELLOW}Enter new SSH port [Default port 22]:${NC} "
        read -r SSH_PORT
        SSH_PORT=${SSH_PORT:-2222}
        
        if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1024 ] || [ "$SSH_PORT" -gt 65535 ]; then
            log_error "Port must be between 1024 and 65535"
            continue
        fi
        
        break
    done
    
    echo ""
    log_info "Configuration Summary:"
    echo "  Username: $NEW_USER"
    echo "  SSH Port: $SSH_PORT"
    echo ""
    
    echo -ne "${YELLOW}Proceed with setup? (yes/no):${NC} "
    read -r confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Setup cancelled"
        exit 0
    fi
}

# System update
system_update() {
    log_step "Step 1: System Update"
    
    if is_debian_based; then
        # Wait for apt locks
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
            log_info "Waiting for other package managers to finish..."
            sleep 5
        done
    fi
    
    log_info "Updating package index..."
    pkg_update
    
    log_info "Upgrading packages..."
    if is_debian_based; then
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
        apt-get autoremove -y
    elif is_rhel_based; then
        dnf upgrade -y || yum upgrade -y
        dnf autoremove -y || yum autoremove -y
    fi
    
    log_success "System updated"
}

# Install security tools
install_security_tools() {
    log_step "Step 2: Installing Security Tools"
    
    local packages=""
    
    # Common packages for all distros
    packages="curl wget git htop vim"
    
    # Add distro-specific packages
    if is_debian_based; then
        packages="$packages ufw fail2ban auditd chrony unattended-upgrades apt-listchanges net-tools libpam-tmpdir"
    elif is_rhel_based; then
        packages="$packages firewalld fail2ban audit chrony dnf-automatic net-tools"
    fi
    
    log_info "Installing: $packages"
    pkg_install $packages
    
    log_success "Security tools installed"
}

# Create admin user
create_admin_user() {
    log_step "Step 3: Setting Up Admin User"
    
    if ! id "$NEW_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$NEW_USER"
        echo "${NEW_USER}:${NEW_PASSWORD}" | chpasswd
        usermod -aG sudo "$NEW_USER"
        log_success "User $NEW_USER created"
    else
        echo "${NEW_USER}:${NEW_PASSWORD}" | chpasswd
        usermod -aG sudo "$NEW_USER"
        log_success "User $NEW_USER updated"
    fi
    
    # Setup SSH directory
    USER_HOME="/home/$NEW_USER"
    mkdir -p "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.ssh"
    
    # Move repository if exists
    REPO_MOVED=false
    if [ -d "/root/my-scripts" ]; then
        log_info "Moving repository to user home..."
        mv /root/my-scripts "$USER_HOME/"
        chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/my-scripts"
        REPO_MOVED=true
        log_success "Repository moved to $USER_HOME/my-scripts"
    fi
    
    log_success "User configuration completed"
}

# Kernel and system hardening
kernel_hardening() {
    log_step "Step 4: Kernel Hardening"
    
    # Secure shared memory
    if ! grep -q "/dev/shm" /etc/fstab; then
        echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
        mount -o remount /dev/shm 2>/dev/null || true
    fi
    
    # Sysctl hardening
    cat > /etc/sysctl.d/99-security.conf <<'EOF'
# IP Forwarding
net.ipv4.ip_forward = 0

# Syn flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096

# IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Ignore ICMP requests
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Kernel security
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
EOF
    
    sysctl -p /etc/sysctl.d/99-security.conf >/dev/null
    
    log_success "Kernel hardened"
}

# Configure SSH
configure_ssh() {
    log_step "Step 5: SSH Hardening"
    
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup_$(date +%Y%m%d_%H%M%S)
    
    # Write directly to /etc/ssh/sshd_config
    cat > /etc/ssh/sshd_config <<EOF
# SSH Daemon Configuration - Hardened
# Generated by vps-initial-setup.sh on $(date)

# Port and Protocol
Port $SSH_PORT
AddressFamily inet
Protocol 2

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security
X11Forwarding no
PrintMotd no
PermitUserEnvironment no
AllowTcpForwarding no
AllowAgentForwarding no
MaxAuthTries 3
MaxSessions 2

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60

# Logging
SyslogFacility AUTH
LogLevel INFO

# Allowed users
AllowUsers $NEW_USER

# Include additional configs if they exist
Include /etc/ssh/sshd_config.d/*.conf
EOF
    
    # Test SSH configuration
    if ! sshd -t 2>/dev/null; then
        log_error "SSH configuration is invalid!"
        log_error "Restoring backup..."
        LATEST_BACKUP=$(ls -t /etc/ssh/sshd_config.backup_* 2>/dev/null | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            cp "$LATEST_BACKUP" /etc/ssh/sshd_config
        fi
        exit 1
    fi
    
    # Get SSH service name for this OS (ssh on Ubuntu/Debian, sshd on RHEL/others)
    SSH_SERVICE=$(get_ssh_service_name)
    log_info "Detected SSH service: $SSH_SERVICE"
    
    # Reload SSH service to apply new configuration
    # Using 'reload' instead of 'restart' to avoid dropping existing connections
    log_info "Reloading SSH service ($SSH_SERVICE) to apply new configuration..."
    if systemctl reload "$SSH_SERVICE" 2>/dev/null; then
        log_success "SSH service reloaded successfully"
    else
        log_warn "Reload failed, attempting restart..."
        if ! systemctl restart "$SSH_SERVICE"; then
            log_error "Failed to restart SSH service!"
            log_error "Restoring backup configuration..."
            LATEST_BACKUP=$(ls -t /etc/ssh/sshd_config.backup_* 2>/dev/null | head -1)
            if [ -n "$LATEST_BACKUP" ]; then
                cp "$LATEST_BACKUP" /etc/ssh/sshd_config
                systemctl restart "$SSH_SERVICE"
            fi
            exit 1
        fi
    fi
    
    # Verify SSH is running
    sleep 2
    if ! systemctl is-active --quiet "$SSH_SERVICE"; then
        log_error "SSH service is not active after reload!"
        exit 1
    fi
    
    log_success "SSH configured on port $SSH_PORT and service reloaded"
}

# Configure firewall
configure_firewall() {
    log_step "Step 6: Firewall Configuration"
    
    # Wait for SSH to fully bind to new port
    log_info "Waiting for SSH to bind to port $SSH_PORT..."
    sleep 3
    
    # Verify SSH is running on new port (check multiple times)
    SSH_LISTENING=false
    for i in {1..5}; do
        if ss -tlnp 2>/dev/null | grep -q ":$SSH_PORT" || netstat -tlnp 2>/dev/null | grep -q ":$SSH_PORT"; then
            SSH_LISTENING=true
            break
        fi
        sleep 1
    done
    
    if [ "$SSH_LISTENING" = false ]; then
        log_error "SSH is not listening on port $SSH_PORT!"
        log_error "Skipping firewall configuration for safety"
        return 1
    fi
    
    log_success "Confirmed SSH is listening on port $SSH_PORT"
    
    # Get firewall type for this OS
    FIREWALL_TYPE=$(get_firewall_service)
    log_info "Using firewall: $FIREWALL_TYPE"
    
    if [ "$FIREWALL_TYPE" = "ufw" ]; then
        # UFW (Ubuntu/Debian)
        ufw --force reset
        
        # Default policies
        ufw default deny incoming
        ufw default allow outgoing
        
        # IMPORTANT: Allow SSH FIRST before enabling firewall
        ufw allow "$SSH_PORT/tcp" comment "SSH"
        
        log_warn "Firewall will be enabled with SSH port $SSH_PORT allowed"
        log_warn "Make sure you can connect on this port before proceeding!"
        
        echo -ne "${YELLOW}Enable firewall now? (yes/no):${NC} "
        read -r confirm
        if [[ "$confirm" != "yes" ]]; then
            log_warn "Firewall configuration skipped - you can enable it later"
            log_info "To enable: ufw allow $SSH_PORT/tcp && ufw --force enable"
            return 0
        fi
        
        # Allow HTTP/HTTPS (for web services)
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        
        # Enable UFW
        ufw --force enable
        
    elif [ "$FIREWALL_TYPE" = "firewalld" ]; then
        # firewalld (RHEL/CentOS/AlmaLinux)
        systemctl enable --now firewalld
        
        # Allow SSH port
        firewall-cmd --permanent --add-port="${SSH_PORT}/tcp"
        
        log_warn "Firewall will be configured with SSH port $SSH_PORT allowed"
        
        # Allow HTTP/HTTPS (for web services)
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        
        # Reload firewall
        firewall-cmd --reload
    else
        log_error "No supported firewall found!"
        return 1
    fi
    
    log_success "Firewall configured and enabled"
}

# Configure Fail2ban
configure_fail2ban() {
    log_step "Step 7: Fail2ban Configuration"
    
    # Get correct log path for this OS
    local SSH_LOG_PATH
    if is_debian_based; then
        SSH_LOG_PATH="/var/log/auth.log"
    elif is_rhel_based; then
        SSH_LOG_PATH="/var/log/secure"
    else
        SSH_LOG_PATH="/var/log/auth.log"
    fi
    
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mw)s

[sshd]
enabled = true
port = $SSH_PORT
logpath = $SSH_LOG_PATH
maxretry = 3
EOF
    
    service_restart fail2ban
    service_enable fail2ban
    
    log_success "Fail2ban configured"
}

# Configure audit logs
configure_audit() {
    log_step "Step 8: Audit Logging"
    
    cat > /etc/audit/rules.d/audit.rules <<'EOF'
# Monitor identity changes
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p warx -k sshd_config

# Monitor sudo usage
-w /etc/sudoers -p wa -k sudoers
-w /var/log/sudo.log -p wa -k sudo_log

# Monitor network configuration
-w /etc/network/ -p wa -k network

# Monitor system calls
-a always,exit -F arch=b64 -S execve -k exec
EOF
    
    systemctl restart auditd
    
    log_success "Audit logging configured"
}

# Configure automatic updates
configure_auto_updates() {
    log_step "Step 9: Automatic Security Updates"
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    log_success "Automatic updates configured"
}

# Set custom MOTD
set_motd() {
    log_step "Step 10: Setting MOTD"
    
    rm -f /etc/update-motd.d/* 2>/dev/null || true
    
    cat > /etc/motd <<'EOF'
═══════════════════════════════════════════════════════════
 ⚠️  WARNING: RESTRICTED ACCESS SYSTEM
═══════════════════════════════════════════════════════════

 All activities on this system are logged and monitored.
 Unauthorized access will be reported and prosecuted.
 
 This server is configured with enterprise security:
 • SSH Hardening
 • Firewall Protection (UFW)
 • Intrusion Prevention (Fail2ban)
 • Audit Logging
 • Automatic Security Updates
 
═══════════════════════════════════════════════════════════
EOF
    
    log_success "MOTD configured"
}

# Final checks
final_checks() {
    log_step "Step 11: Final Verification"
    
    # Check services
    local services=("ssh" "ufw" "fail2ban" "auditd")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_success "$service is running"
        else
            log_warn "$service is not running"
        fi
    done
    
    # Check firewall rules
    log_info "Firewall status:"
    ufw status numbered
}

# Main execution
main() {
    # Check if root
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    print_banner
    
    log_warn "This script will configure and harden your VPS"
    log_warn "Make sure you have console access in case of issues!"
    echo ""
    
    gather_information
    
    echo ""
    log_info "Starting VPS setup and hardening..."
    echo ""
    
    system_update
    install_security_tools
    create_admin_user
    kernel_hardening
    configure_ssh
    configure_firewall
    configure_fail2ban
    configure_audit
    configure_auto_updates
    set_motd
    final_checks
    
    echo ""
    echo ""
    log_success "═══════════════════════════════════════════"
    log_success "  VPS Setup Completed Successfully!"
    log_success "═══════════════════════════════════════════"
    echo ""
    log_info "Configuration Summary:"
    echo "  • New User:     $NEW_USER"
    echo "  • SSH Port:     $SSH_PORT"
    echo "  • Server IP:    $(hostname -I | awk '{print $1}')"
    echo "  • Root Access:  Available via 'su -' command"
    echo ""
    
    if [ "$REPO_MOVED" = true ]; then
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "  REPOSITORY LOCATION"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  Repository moved from /root/my-scripts to:"
        echo "  /home/$NEW_USER/my-scripts"
        echo ""
        echo "  After login, access it with:"
        echo "    cd ~/my-scripts"
        echo ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    fi
    
    log_info "Connection Instructions:"
    echo ""
    echo "  Connect with password:"
    echo "    ssh $NEW_USER@$(hostname -I | awk '{print $1}') -p $SSH_PORT"
    echo ""
    echo "  Switch to root when needed:"
    echo "    su -"
    echo ""
    
    log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_warn "  IMPORTANT: TEST CONNECTION NOW!"
    log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Open a NEW terminal and test connection:"
    echo ""
    echo "    ssh $NEW_USER@$(hostname -I | awk '{print $1}') -p $SSH_PORT"
    echo ""
    echo "  If connection works:"
    echo "    ✓ Type 'sudo whoami' to verify sudo access"
    echo "    ✓ Type 'su -' to switch to root"
    echo "    ✓ You can safely close THIS root session"
    if [ "$REPO_MOVED" = true ]; then
        echo "    ✓ All scripts available in: ~/my-scripts/"
    fi
    echo ""
    echo "  If connection FAILS:"
    echo "    1. Check: systemctl status sshd"
    echo "    2. Check: ss -tlnp | grep $SSH_PORT"
    echo "    3. Check: ufw status"
    echo "    4. Try: ufw allow $SSH_PORT/tcp"
    echo ""
    log_warn "⚠️  DO NOT CLOSE THIS ROOT SESSION UNTIL VERIFIED!"
    echo ""
}

# Run
main
