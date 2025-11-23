#!/bin/bash
################################################################################
# Common utilities for TacticalRMM installation scripts
# Source this file in all installation scripts
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
SECRETS_FILE="${SCRIPT_DIR}/.secrets.env"

################################################################################
# Configuration Loading
################################################################################

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}ERROR: Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi

    # Load configuration
    set -a
    source "$CONFIG_FILE"
    set +a

    # Load or generate secrets
    if [[ -f "$SECRETS_FILE" ]]; then
        source "$SECRETS_FILE"
    else
        generate_secrets
    fi
}

generate_secrets() {
    # Generate secure random passwords if not already set
    [[ -z "$POSTGRES_PASSWORD" ]] && POSTGRES_PASSWORD=$(openssl rand -base64 32)
    [[ -z "$REDIS_PASSWORD" ]] && REDIS_PASSWORD=$(openssl rand -base64 32)
    [[ -z "$ADMIN_PASSWORD" ]] && ADMIN_PASSWORD=$(openssl rand -base64 24)
    [[ -z "$MESH_TOKEN" ]] && MESH_TOKEN=$(openssl rand -hex 32)
    [[ -z "$DJANGO_SECRET" ]] && DJANGO_SECRET=$(openssl rand -base64 64 | tr -d '\n')

    # Save secrets to file
    cat > "$SECRETS_FILE" <<EOF
# Auto-generated secrets - DO NOT COMMIT TO VERSION CONTROL
POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
REDIS_PASSWORD="${REDIS_PASSWORD}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
MESH_TOKEN="${MESH_TOKEN}"
DJANGO_SECRET="${DJANGO_SECRET}"
EOF

    chmod 600 "$SECRETS_FILE"
}

################################################################################
# Logging Functions
################################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

################################################################################
# Validation Functions
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_ubuntu() {
    if ! grep -q "Ubuntu 24.04" /etc/os-release; then
        error "This script is designed for Ubuntu 24.04 LTS only"
    fi
}

check_resources() {
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)

    if [[ $total_ram -lt 7 ]]; then
        warn "Less than 8GB RAM detected (${total_ram}GB). TacticalRMM may not perform optimally."
    fi

    if [[ $cpu_cores -lt 4 ]]; then
        warn "Less than 4 CPU cores detected (${cpu_cores}). TacticalRMM may not perform optimally."
    fi

    log "System Resources: ${total_ram}GB RAM, ${cpu_cores} CPU cores"
}

################################################################################
# Service Management
################################################################################

check_service_status() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        log "✓ $service is running"
        return 0
    else
        warn "✗ $service is not running"
        return 1
    fi
}

enable_and_start_service() {
    local service=$1
    systemctl enable "$service" || warn "Failed to enable $service"
    systemctl start "$service" || warn "Failed to start $service"
    sleep 2
    check_service_status "$service"
}

################################################################################
# File Operations
################################################################################

create_directory() {
    local dir=$1
    local owner=${2:-root}
    local group=${3:-root}
    local perms=${4:-755}

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chown "${owner}:${group}" "$dir"
        chmod "$perms" "$dir"
        log "Created directory: $dir"
    fi
}

backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        log "Backed up $file to $backup"
    fi
}

################################################################################
# Installation Helpers
################################################################################

install_packages() {
    local packages=("$@")
    log "Installing packages: ${packages[*]}"
    apt-get install -y "${packages[@]}" || error "Failed to install packages: ${packages[*]}"
}

################################################################################
# Initialize
################################################################################

# Load configuration when this library is sourced
load_config
