#!/bin/bash

# ==============================================================================
# INPUT VALIDATORS LIBRARY
# Provides validation functions for user input
# ==============================================================================

set -euo pipefail

# Validate port number
# Args: $1 = port number
validate_port() {
    local port=$1
    
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        log_error "Port must be a number"
        return 1
    fi
    
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Port must be between 1 and 65535"
        return 1
    fi
    
    # Check if port is already in use
    if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        log_warn "Port $port is already in use"
        return 2
    fi
    
    return 0
}

# Validate domain name
# Args: $1 = domain
validate_domain() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        log_error "Domain cannot be empty"
        return 1
    fi
    
    # Basic domain regex validation
    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $domain"
        return 1
    fi
    
    return 0
}

# Validate email address
# Args: $1 = email
validate_email() {
    local email=$1
    
    if [ -z "$email" ]; then
        log_error "Email cannot be empty"
        return 1
    fi
    
    # Basic email regex validation
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid email format: $email"
        return 1
    fi
    
    return 0
}

# Validate username
# Args: $1 = username
validate_username() {
    local username=$1
    
    if [ -z "$username" ]; then
        log_error "Username cannot be empty"
        return 1
    fi
    
    # Username: alphanumeric, underscore, hyphen, 3-32 chars
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]{3,32}$ ]]; then
        log_error "Username must be 3-32 characters (alphanumeric, underscore, hyphen)"
        return 1
    fi
    
    # Check if username already exists
    if id "$username" &>/dev/null; then
        log_warn "User $username already exists"
        return 2
    fi
    
    return 0
}

# Validate password strength
# Args: $1 = password
validate_password() {
    local password=$1
    local min_length=8
    
    if [ -z "$password" ]; then
        log_error "Password cannot be empty"
        return 1
    fi
    
    if [ ${#password} -lt $min_length ]; then
        log_error "Password must be at least $min_length characters"
        return 1
    fi
    
    # Check for at least one letter and one number
    if [[ ! "$password" =~ [a-zA-Z] ]] || [[ ! "$password" =~ [0-9] ]]; then
        log_warn "Password should contain both letters and numbers"
        return 2
    fi
    
    return 0
}

# Validate IP address
# Args: $1 = ip_address
validate_ip() {
    local ip=$1
    
    if [ -z "$ip" ]; then
        log_error "IP address cannot be empty"
        return 1
    fi
    
    # IPv4 validation
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                log_error "Invalid IP address: $ip"
                return 1
            fi
        done
        return 0
    fi
    
    log_error "Invalid IP address format: $ip"
    return 1
}

# Validate path exists
# Args: $1 = path
validate_path_exists() {
    local path=$1
    
    if [ -z "$path" ]; then
        log_error "Path cannot be empty"
        return 1
    fi
    
    if [ ! -e "$path" ]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    
    return 0
}

# Validate directory is writable
# Args: $1 = directory
validate_writable_dir() {
    local dir=$1
    
    if [ -z "$dir" ]; then
        log_error "Directory path cannot be empty"
        return 1
    fi
    
    if [ ! -d "$dir" ]; then
        log_error "Not a directory: $dir"
        return 1
    fi
    
    if [ ! -w "$dir" ]; then
        log_error "Directory not writable: $dir"
        return 1
    fi
    
    return 0
}

# Validate yes/no input
# Args: $1 = input
validate_yes_no() {
    local input=$1
    
    if [[ "$input" =~ ^[Yy](es)?$ ]] || [[ "$input" =~ ^[Nn](o)?$ ]]; then
        return 0
    fi
    
    log_error "Please answer yes or no (y/n)"
    return 1
}

# Validate number in range
# Args: $1 = number, $2 = min, $3 = max
validate_number_range() {
    local number=$1
    local min=$2
    local max=$3
    
    if [[ ! "$number" =~ ^[0-9]+$ ]]; then
        log_error "Value must be a number"
        return 1
    fi
    
    if [ "$number" -lt "$min" ] || [ "$number" -gt "$max" ]; then
        log_error "Value must be between $min and $max"
        return 1
    fi
    
    return 0
}

# Sanitize input (remove dangerous characters)
# Args: $1 = input string
sanitize_input() {
    local input=$1
    
    # Remove shell special characters
    echo "$input" | sed 's/[;&|`$()<>]//g'
}

# Prompt for input with validation
# Args: $1 = prompt message, $2 = validation function, $3 = default value (optional)
prompt_with_validation() {
    local prompt_msg=$1
    local validator=$2
    local default=${3:-""}
    local input
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        echo ""
        if [ -n "$default" ]; then
            echo -n "${YELLOW}${prompt_msg} [${default}]:${NC} "
        else
            echo -n "${YELLOW}${prompt_msg}:${NC} "
        fi
        
        read -r input
        
        # Use default if input is empty
        if [ -z "$input" ] && [ -n "$default" ]; then
            input="$default"
        fi
        
        # Validate input
        if $validator "$input"; then
            echo "$input"
            return 0
        fi
        
        attempts=$((attempts + 1))
        if [ $attempts -lt $max_attempts ]; then
            log_warn "Please try again ($((max_attempts - attempts)) attempts remaining)"
        fi
    done
    
    log_error "Maximum attempts reached"
    return 1
}

# Prompt for password (hidden input) with confirmation
# Args: $1 = prompt message
prompt_password() {
    local prompt_msg=${1:-"Enter password"}
    local password1
    local password2
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        echo ""
        echo -n "${YELLOW}${prompt_msg}:${NC} "
        read -s password1
        echo ""
        
        if ! validate_password "$password1"; then
            attempts=$((attempts + 1))
            continue
        fi
        
        echo -n "${YELLOW}Confirm password:${NC} "
        read -s password2
        echo ""
        
        if [ "$password1" = "$password2" ]; then
            echo "$password1"
            return 0
        else
            log_error "Passwords do not match"
            attempts=$((attempts + 1))
        fi
    done
    
    log_error "Maximum attempts reached"
    return 1
}

# Check if command exists
# Args: $1 = command name
command_exists() {
    command -v "$1" &> /dev/null
}

# Check disk space
# Args: $1 = path, $2 = required space in GB
check_disk_space() {
    local path=$1
    local required_gb=$2
    
    local available_kb=$(df -k "$path" | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        log_error "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 1
    fi
    
    log_info "Disk space OK: ${available_gb}GB available"
    return 0
}

# Check memory availability
# Args: $1 = required memory in GB
check_memory() {
    local required_gb=$1
    
    local available_mb=$(free -m | awk 'NR==2 {print $7}')
    local available_gb=$((available_mb / 1024))
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        log_warn "Low memory. Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 2
    fi
    
    log_info "Memory OK: ${available_gb}GB available"
    return 0
}
