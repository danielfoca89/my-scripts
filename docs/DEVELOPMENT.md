# 🛠️ Development Guide - Adding New Applications

## Quick Reference for Adding Applications

### Step 1: Create Application Directory
```bash
mkdir -p apps/CATEGORY/APP_NAME
cd apps/CATEGORY/APP_NAME
```

### Step 2: Create install.sh
```bash
#!/bin/bash

# Get script directory (3 levels up to reach orchestrator root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Load libraries
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

APP_NAME="your-app-name"
CONTAINER_NAME="your-container-name"
DATA_DIR="/opt/apps/${APP_NAME}"

log_info "═══════════════════════════════════════════"
log_info "  Installing ${APP_NAME}"
log_info "═══════════════════════════════════════════"
echo ""

# STEP 1: Check Dependencies
log_step "Step 1: Checking dependencies"
if ! check_docker; then
    log_error "Docker is not installed"
    exit 1
fi

# STEP 2: Generate/Load Credentials
log_step "Step 2: Managing credentials"
init_secrets_dir

if ! has_credentials "$APP_NAME"; then
    log_info "Generating new credentials..."
    
    # Generate passwords
    APP_PASSWORD=$(generate_secure_password 32 "alphanumeric")
    API_KEY=$(generate_secure_password 64 "alphanumeric")
    
    # Save credentials
    save_secret "$APP_NAME" "APP_PASSWORD" "$APP_PASSWORD"
    save_secret "$APP_NAME" "API_KEY" "$API_KEY"
fi

# Load credentials
load_secrets "$APP_NAME"

# STEP 3: Setup Network
log_step "Step 3: Setting up Docker network"
create_docker_network "vps_network"

# STEP 4: Create Directories
log_step "Step 4: Creating data directories"
create_app_directory "$DATA_DIR" 755
create_app_directory "$DATA_DIR/data" 755
create_app_directory "$DATA_DIR/config" 755

# STEP 5: Remove Existing Container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_info "Removing existing container..."
    remove_container "$CONTAINER_NAME"
fi

# STEP 6: Deploy Container
log_step "Step 5: Deploying container"
log_info "Using image: your-image:tag"

run_sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network vps_network \
    -e APP_PASSWORD="$APP_PASSWORD" \
    -e API_KEY="$API_KEY" \
    -v "${DATA_DIR}/data":/app/data \
    -v "${DATA_DIR}/config":/app/config \
    -p 8080:8080 \
    --health-cmd="curl -f http://localhost:8080/health || exit 1" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    your-image:tag

# STEP 7: Verify Installation
log_step "Step 6: Verifying installation"
if check_container_health "$CONTAINER_NAME" 30; then
    log_success "${APP_NAME} is running and healthy!"
else
    log_error "Health check failed"
    show_container_logs "$CONTAINER_NAME" 20
    exit 1
fi

# STEP 8: Display Information
echo ""
log_success "═══════════════════════════════════════════"
log_success "  ${APP_NAME} installed successfully!"
log_success "═══════════════════════════════════════════"
echo ""

log_info "Container Details:"
echo "  Name:       $CONTAINER_NAME"
echo "  Network:    vps_network"
echo "  Port:       8080"
echo "  Data Dir:   $DATA_DIR"
echo ""

log_info "Access URL:"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "  http://${SERVER_IP}:8080"
echo ""

log_warn "Credentials stored in: ~/.vps-secrets/.env_${APP_NAME}"
echo ""
```

### Step 3: Make Executable
```bash
chmod +x install.sh
```

### Step 4: Create README.md
```markdown
# Application Name

Short description of the application.

## Features
- Feature 1
- Feature 2
- Feature 3

## Installation
Automatically configures:
- Docker container
- Auto-generated credentials
- Data persistence
- Health checks

## Credentials
Stored securely in: `~/.vps-secrets/.env_appname`

## Usage
```bash
# Access application
http://SERVER_IP:PORT

# View logs
docker logs container-name

# Restart
docker restart container-name
```

## Management
Common commands for managing the application.
```

### Step 5: Update config/apps.conf
```ini
[your-app-name]
category=databases
display_name=Your App Name
description=Short description
requires_domain=no
requires_ssl=no
dependencies=docker-engine
default_port=8080
secrets=APP_PASSWORD,API_KEY
```

---

## 📝 Best Practices

### Credential Management
```bash
# Generate secure passwords
PASSWORD=$(generate_secure_password 32 "alphanumeric")
PASSWORD=$(generate_secure_password 32 "alphanumeric_special")
TOKEN=$(generate_secure_password 64 "alphanumeric")

# Save credentials
save_secret "$APP_NAME" "VAR_NAME" "$value"

# Load credentials
load_secrets "$APP_NAME"

# Check if exists
if has_credentials "$APP_NAME"; then
    # Load existing
else
    # Generate new
fi
```

### Docker Best Practices
```bash
# Always use health checks
--health-cmd="curl -f http://localhost:8080/health || exit 1"
--health-interval=30s
--health-timeout=10s
--health-retries=3

# Use Docker networks
--network vps_network

# Use restart policy
--restart unless-stopped

# Use volumes for data
-v "${DATA_DIR}/data":/app/data

# Set resource limits (optional)
--memory="512m"
--cpus="0.5"
```

### Error Handling
```bash
# Check dependencies
if ! check_docker; then
    log_error "Docker is not installed"
    exit 1
fi

# Check deployment
if check_container_health "$CONTAINER_NAME"; then
    log_success "Installation successful!"
else
    log_error "Installation failed"
    show_container_logs "$CONTAINER_NAME" 20
    exit 1
fi
```

---

## 🔍 Available Library Functions

### utils.sh
```bash
log_info "message"      # Info message
log_warn "message"      # Warning message
log_error "message"     # Error message
log_success "message"   # Success message
log_step "message"      # Step indicator
run_sudo command        # Execute with sudo
detect_os               # Detect OS and package manager
open_port PORT "desc"   # Open firewall port
install_package name    # Install system package
require_dependency path # Check dependency
create_app_directory    # Create directory with permissions
backup_file path        # Backup a file
enable_service name     # Enable systemd service
get_public_ip           # Get server public IP
```

### secrets.sh
```bash
init_secrets_dir                        # Initialize secrets directory
generate_secure_password LENGTH CHARSET # Generate password
save_secret APP VAR VALUE              # Save a secret
load_secrets APP                       # Load secrets
has_credentials APP                    # Check if exists
get_secret APP VAR                     # Get specific secret
display_connection_info APP            # Display credentials
list_all_secrets                       # List all stored secrets
backup_secrets                         # Backup all secrets
regenerate_secrets APP                 # Regenerate secrets
delete_secrets APP                     # Delete secrets
export_secrets APP FILE                # Export secrets
import_secrets APP FILE                # Import secrets
```

### docker.sh
```bash
check_docker                    # Check if Docker is running
check_docker_compose            # Check Docker Compose availability
create_docker_network NAME      # Create network
deploy_with_compose DIR         # Deploy with docker-compose
remove_container NAME           # Remove container
check_container_health NAME     # Check health status
show_container_logs NAME        # Show logs
restart_container NAME          # Restart container
list_containers                 # List all containers
get_container_ip NAME NETWORK   # Get container IP
pull_docker_image IMAGE         # Pull image
image_exists IMAGE              # Check if image exists
create_volume NAME              # Create volume
remove_volume NAME              # Remove volume
docker_cleanup                  # Cleanup unused resources
```

### validators.sh
```bash
validate_port PORT              # Validate port number
validate_domain DOMAIN          # Validate domain
validate_email EMAIL            # Validate email
validate_username USER          # Validate username
validate_password PASS          # Validate password strength
validate_ip IP                  # Validate IP address
validate_path_exists PATH       # Check path exists
validate_writable_dir DIR       # Check directory writable
validate_yes_no INPUT           # Validate y/n input
validate_number_range NUM MIN MAX # Validate number range
prompt_with_validation MSG FUNC # Prompt with validation
prompt_password MSG             # Prompt for password (hidden)
command_exists CMD              # Check if command exists
check_disk_space PATH GB        # Check disk space
check_memory GB                 # Check available memory
```

---

## 🐳 Docker Compose Example

If using docker-compose instead of docker run:

```yaml
# docker-compose.yml
version: '3.9'

services:
  app-name:
    image: your-image:tag
    container_name: app-name
    restart: unless-stopped
    environment:
      - APP_PASSWORD=${APP_PASSWORD}
      - API_KEY=${API_KEY}
    volumes:
      - ./data:/app/data
      - ./config:/app/config
    networks:
      - vps_network
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  vps_network:
    external: true

volumes:
  app_data:
    driver: local
```

Deploy with:
```bash
# Create .env file
cat > "$DATA_DIR/.env" <<EOF
APP_PASSWORD=${APP_PASSWORD}
API_KEY=${API_KEY}
EOF

# Deploy
cd "$DATA_DIR"
deploy_with_compose "$DATA_DIR"
```

---

## 🧪 Testing Your Application

```bash
# Test the install script
cd /path/to/vps-orchestrator
./apps/category/app-name/install.sh

# Check container
docker ps | grep app-name
docker logs app-name

# Check credentials
cat ~/.vps-secrets/.env_app-name

# Test via orchestrator
./orchestrator.sh
# Navigate to your category and app
```

---

## 📚 Examples to Follow

### Simple Application (like Redis)
- `apps/databases/postgres/install.sh`
- Single container
- Auto-generated credentials
- No dependencies beyond Docker

### Complex Application (like n8n)
- Multiple dependencies (Docker, PostgreSQL)
- Requires domain and SSL
- Database integration
- Environment configuration

### System Tool (like VPS Setup)
- `workflows/vps-initial-setup.sh`
- No Docker required
- System configuration
- Multiple steps

---

## 💡 Tips

1. **Start Simple**: Copy postgres install.sh as template
2. **Test Incrementally**: Test each step as you add it
3. **Use Health Checks**: Always include container health checks
4. **Document Well**: Good README helps users
5. **Handle Errors**: Check dependencies and handle failures gracefully
6. **Secure Credentials**: Always use secrets.sh, never hardcode
7. **Clean Up**: Remove old containers before deploying new ones

---

## 🤝 Contributing

1. Create your application in appropriate category
2. Follow the established patterns
3. Test thoroughly
4. Update config/apps.conf
5. Create good documentation
6. Submit your work!

---

**Happy Coding! 🚀**
