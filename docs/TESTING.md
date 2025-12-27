# ✅ Testing Checklist - VPS Orchestrator v2.0

## Pre-Testing Setup

### Environment
- [ ] Fresh Ubuntu/Debian VPS or VM
- [ ] Root or sudo access
- [ ] Internet connectivity
- [ ] Minimum 2GB RAM, 20GB disk

### Clone Repository
```bash
git clone https://github.com/danielfoca89/my-scripts.git
cd my-scripts
```

---

## 🧪 Test Suite 1: Core Functionality

### Test 1.1: Orchestrator Launch
```bash
./orchestrator.sh
```
**Expected**:
- [ ] ASCII banner displays
- [ ] Main menu with 8 options visible
- [ ] Categories numbered 1-6
- [ ] Manage Secrets (7) and Help (8) visible
- [ ] Exit option (0) present

### Test 1.2: Menu Navigation
**Test Case**: Navigate through menus
```
1. Select [1] Databases
2. Observe application list
3. Select [b] Back
4. Return to main menu
```
**Expected**:
- [ ] Category menu displays correctly
- [ ] Breadcrumb shows "Main > Databases"
- [ ] Back returns to main menu
- [ ] Breadcrumb updates to "Main"

### Test 1.3: Invalid Input Handling
**Test Case**: Enter invalid option "99"
**Expected**:
- [ ] Error message "Invalid option"
- [ ] Menu redisplays
- [ ] No crash or exit

---

## 🧪 Test Suite 2: Docker Engine Installation

### Test 2.1: Install Docker
```bash
./orchestrator.sh
# Navigate: Infrastructure > Docker Engine
```
**Expected**:
- [ ] Checks for existing Docker
- [ ] Installs Docker CE + Compose
- [ ] Creates vps_network
- [ ] Starts Docker service
- [ ] Shows version information
- [ ] No errors in output

### Test 2.2: Verify Docker Installation
```bash
docker --version
docker compose version
docker network ls | grep vps_network
docker ps
```
**Expected**:
- [ ] Docker version displays
- [ ] Compose version displays
- [ ] vps_network exists
- [ ] No containers running yet

### Test 2.3: Docker Group Membership
```bash
groups | grep docker
# Or after logout/login
docker ps
```
**Expected**:
- [ ] User is in docker group
- [ ] Docker commands work without sudo

---

## 🧪 Test Suite 3: PostgreSQL Installation

### Test 3.1: Install PostgreSQL
```bash
./orchestrator.sh
# Navigate: Databases > PostgreSQL
```
**Expected**:
- [ ] Checks Docker dependency
- [ ] Generates credentials
- [ ] Creates container "postgres"
- [ ] Container starts and is healthy
- [ ] Displays connection information
- [ ] No errors

### Test 3.2: Verify Container
```bash
docker ps | grep postgres
docker logs postgres
docker exec postgres pg_isready -U postgres
```
**Expected**:
- [ ] Container is running
- [ ] Logs show successful startup
- [ ] pg_isready returns "accepting connections"

### Test 3.3: Verify Credentials
```bash
cat ~/.vps-secrets/.env_postgres
ls -la ~/.vps-secrets/
```
**Expected**:
- [ ] File exists
- [ ] Contains DB_PASSWORD, POSTGRES_USER, POSTGRES_DB
- [ ] File permissions are 600
- [ ] Directory permissions are 700

### Test 3.4: Test Database Connection
```bash
# Get password
source ~/.vps-secrets/.env_postgres
# Connect to database
docker exec -it postgres psql -U postgres -c "SELECT version();"
```
**Expected**:
- [ ] Connection successful
- [ ] PostgreSQL version displays
- [ ] No authentication errors

---

## 🧪 Test Suite 4: Secret Management

### Test 4.1: List Secrets
```bash
./orchestrator.sh --list-secrets
```
**Expected**:
- [ ] Shows postgres credentials
- [ ] Displays variable count
- [ ] Shows last modified date
- [ ] Credentials are masked

### Test 4.2: View Specific App Secrets
```bash
./orchestrator.sh
# Navigate: Manage Secrets > View Specific App
# Enter: postgres
```
**Expected**:
- [ ] Displays connection information
- [ ] Shows masked credentials
- [ ] Shows file location

### Test 4.3: Backup Secrets
```bash
./orchestrator.sh --backup-secrets
ls -la ~/.vps-secrets/.backup/
```
**Expected**:
- [ ] Backup created
- [ ] Filename contains timestamp
- [ ] File is .tar.gz
- [ ] Permissions are 600

### Test 4.4: Reinstall with Existing Credentials
```bash
./orchestrator.sh
# Install PostgreSQL again
```
**Expected**:
- [ ] Detects existing credentials
- [ ] Asks to reinstall
- [ ] Uses same credentials (doesn't regenerate)
- [ ] Container recreated successfully

---

## 🧪 Test Suite 5: VPS Initial Setup

### Test 5.1: Run VPS Setup (Dry Run - Review Only)
```bash
# DO NOT RUN ON PRODUCTION!
# Test on VM or test VPS only
sudo ./workflows/vps-initial-setup.sh
```
**Inputs to test**:
- Username: testadmin
- Password: TestPass123!
- SSH Port: 2222

**Expected**:
- [ ] Prompts for username (validates format)
- [ ] Prompts for password (validates length)
- [ ] Prompts for SSH port (validates range)
- [ ] Shows configuration summary
- [ ] Asks for confirmation

### Test 5.2: Verify VPS Setup Changes (If Run)
```bash
# Check user
id testadmin

# Check SSH config
cat /etc/ssh/sshd_config.d/99-hardening.conf

# Check firewall
sudo ufw status

# Check fail2ban
sudo systemctl status fail2ban

# Check audit
sudo systemctl status auditd
```
**Expected**:
- [ ] User exists and is in sudo group
- [ ] SSH config has custom port
- [ ] Firewall is active with rules
- [ ] Fail2ban is running
- [ ] Auditd is running

---

## 🧪 Test Suite 6: Error Handling

### Test 6.1: Install PostgreSQL Without Docker
```bash
# Stop Docker
sudo systemctl stop docker

# Try to install PostgreSQL
./orchestrator.sh
# Navigate: Databases > PostgreSQL
```
**Expected**:
- [ ] Error message: "Docker is not installed"
- [ ] Suggests installing Docker first
- [ ] Exits gracefully
- [ ] No container created

### Test 6.2: Invalid Menu Input
```bash
./orchestrator.sh
# Enter: abc
```
**Expected**:
- [ ] Error: "Invalid option"
- [ ] Returns to menu
- [ ] No crash

### Test 6.3: Ctrl+C Handling
```bash
./orchestrator.sh
# Press Ctrl+C during menu
```
**Expected**:
- [ ] Graceful exit
- [ ] Cleanup performed
- [ ] No zombie processes

---

## 🧪 Test Suite 7: Multi-Container Setup

### Test 7.1: Install Multiple Databases
```bash
./orchestrator.sh

# Install PostgreSQL
# Install MariaDB (when implemented)
# Install Redis (when implemented)
```
**Expected**:
- [ ] Each gets separate credentials
- [ ] Each in separate container
- [ ] All on vps_network
- [ ] No port conflicts
- [ ] All credentials in ~/.vps-secrets/

### Test 7.2: Network Communication
```bash
# Test container-to-container communication
docker exec postgres ping -c 3 mariadb
docker network inspect vps_network
```
**Expected**:
- [ ] Containers can ping each other
- [ ] All on same network
- [ ] DNS resolution works

---

## 🧪 Test Suite 8: Documentation

### Test 8.1: README Accuracy
```bash
cat README.md
```
**Check**:
- [ ] Commands are correct
- [ ] Examples work as shown
- [ ] Links are valid
- [ ] Instructions are clear

### Test 8.2: Help Menu
```bash
./orchestrator.sh --help
```
**Expected**:
- [ ] Usage information displays
- [ ] All options documented
- [ ] Examples provided

### Test 8.3: Application README
```bash
cat apps/databases/postgres/README.md
```
**Check**:
- [ ] Installation steps correct
- [ ] Commands work
- [ ] Examples are accurate

---

## 🧪 Test Suite 9: Performance & Resource Usage

### Test 9.1: Startup Time
```bash
time ./orchestrator.sh --help
```
**Expected**:
- [ ] Starts in < 1 second
- [ ] No delays or hangs

### Test 9.2: Container Resource Usage
```bash
docker stats --no-stream
```
**Expected**:
- [ ] PostgreSQL < 100MB RAM
- [ ] CPU usage reasonable
- [ ] No memory leaks

### Test 9.3: Disk Usage
```bash
du -sh ~/.vps-secrets/
du -sh /opt/databases/
docker system df
```
**Expected**:
- [ ] Secrets dir < 1MB
- [ ] Database data dir size is reasonable
- [ ] Docker volumes tracked

---

## 🧪 Test Suite 10: Security

### Test 10.1: File Permissions
```bash
ls -la ~/.vps-secrets/
ls -la ~/.vps-secrets/.env_*
```
**Expected**:
- [ ] Directory is 700
- [ ] Files are 600
- [ ] Owned by current user

### Test 10.2: Password Strength
```bash
cat ~/.vps-secrets/.env_postgres
```
**Check**:
- [ ] Password is 32+ characters
- [ ] Mix of alphanumeric characters
- [ ] No dictionary words
- [ ] Cryptographically random

### Test 10.3: No Exposed Secrets
```bash
# Check containers don't expose secrets in env
docker inspect postgres | grep -i password
# Should only show variable names, not values in most places
```

---

## 📊 Test Results Template

### Environment
- OS: _______________
- RAM: _______________
- Disk: _______________
- Date: _______________

### Results Summary
| Test Suite | Status | Notes |
|------------|--------|-------|
| 1. Core Functionality | ⬜ | |
| 2. Docker Engine | ⬜ | |
| 3. PostgreSQL | ⬜ | |
| 4. Secret Management | ⬜ | |
| 5. VPS Setup | ⬜ | |
| 6. Error Handling | ⬜ | |
| 7. Multi-Container | ⬜ | |
| 8. Documentation | ⬜ | |
| 9. Performance | ⬜ | |
| 10. Security | ⬜ | |

### Issues Found
1. _________________
2. _________________
3. _________________

### Overall Status
- [ ] ✅ All tests passed
- [ ] ⚠️ Minor issues found
- [ ] ❌ Major issues found

---

## 🚀 Production Readiness Checklist

Before using in production:
- [ ] All core tests passed
- [ ] Security audit completed
- [ ] Backup procedures tested
- [ ] Documentation reviewed
- [ ] Recovery procedures documented
- [ ] Monitoring configured
- [ ] Alerts configured

---

**Testing Date**: _______________  
**Tester**: _______________  
**Version Tested**: 2.0.0  
**Result**: ⬜ Pass / ⬜ Fail
