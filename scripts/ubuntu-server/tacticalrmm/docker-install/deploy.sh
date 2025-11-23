#!/bin/bash
################################################################################
# TacticalRMM Docker Deployment Script
# For Ubuntu with Docker and Docker Compose
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_docker() {
    log "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
    fi

    log "Docker version: $(docker --version)"
    if docker compose version &> /dev/null; then
        log "Docker Compose version: $(docker compose version)"
        COMPOSE_CMD="docker compose"
    else
        log "Docker Compose version: $(docker-compose --version)"
        COMPOSE_CMD="docker-compose"
    fi
}

generate_passwords() {
    log "Generating secure passwords..."

    POSTGRES_PASSWORD=$(openssl rand -base64 32)
    REDIS_PASSWORD=$(openssl rand -base64 32)
    DJANGO_SECRET=$(openssl rand -base64 50)
    MESH_TOKEN=$(openssl rand -base64 32)
    ADMIN_PASSWORD=$(openssl rand -base64 16)
}

create_env_file() {
    log "Creating .env file..."

    if [[ -f .env ]]; then
        warn ".env file already exists. Backing up to .env.backup"
        cp .env .env.backup
    fi

    read -p "Enter domain (default: tacticalrmm.hoyt.local): " DOMAIN
    DOMAIN=${DOMAIN:-tacticalrmm.hoyt.local}

    cat > .env <<EOF
# Domain Configuration
DOMAIN=${DOMAIN}
API_DOMAIN=api.${DOMAIN}
MESH_DOMAIN=mesh.${DOMAIN}
RMM_DOMAIN=${DOMAIN}

# PostgreSQL Configuration
POSTGRES_DB=tacticalrmm
POSTGRES_USER=tactical
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Redis Configuration
REDIS_PASSWORD=${REDIS_PASSWORD}

# Django Configuration
DJANGO_SECRET=${DJANGO_SECRET}
ADMIN_USERNAME=admin
ADMIN_EMAIL=admin@${DOMAIN}
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# MeshCentral Configuration
MESH_USER=tactical
MESH_TOKEN=${MESH_TOKEN}

# Application Configuration
GUNICORN_WORKERS=4
GUNICORN_TIMEOUT=300
EOF

    log ".env file created successfully"
}

setup_ssl() {
    log "Setting up SSL certificates..."

    if [[ ! -d ssl ]]; then
        mkdir -p ssl
    fi

    if [[ -f ssl/cert.crt ]] && [[ -f ssl/cert.key ]]; then
        log "SSL certificates already exist"
        return
    fi

    warn "SSL certificates not found in ./ssl/"
    read -p "Do you want to generate self-signed certificates? (y/N): " generate_ssl

    if [[ "$generate_ssl" =~ ^[Yy]$ ]]; then
        log "Generating self-signed SSL certificates..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/cert.key \
            -out ssl/cert.crt \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=*.${DOMAIN}"
        chmod 644 ssl/cert.crt
        chmod 600 ssl/cert.key
        log "Self-signed certificates generated"
    else
        warn "Please place your SSL certificates in ./ssl/ directory:"
        warn "  - ./ssl/cert.crt"
        warn "  - ./ssl/cert.key"
        read -p "Press Enter when certificates are in place, or Ctrl+C to cancel..."
    fi
}

update_nginx_config() {
    log "Updating nginx configuration with domain names..."

    # Replace environment variables in nginx config
    envsubst '${API_DOMAIN} ${RMM_DOMAIN} ${MESH_DOMAIN}' \
        < nginx/conf.d/tacticalrmm.conf \
        > nginx/conf.d/tacticalrmm.conf.tmp
    mv nginx/conf.d/tacticalrmm.conf.tmp nginx/conf.d/tacticalrmm.conf
}

pull_images() {
    log "Pulling Docker images..."
    $COMPOSE_CMD pull
}

build_images() {
    log "Building custom Docker images..."
    $COMPOSE_CMD build --no-cache
}

start_services() {
    log "Starting services..."
    $COMPOSE_CMD up -d

    log "Waiting for services to be ready..."
    sleep 10

    log "Checking service status..."
    $COMPOSE_CMD ps
}

print_summary() {
    local env_file="${SCRIPT_DIR}/.env"

    # Source the .env file to get variables
    set -a
    source "$env_file"
    set +a

    echo ""
    echo "================================================================================"
    echo -e "${GREEN}TacticalRMM Docker Installation Complete!${NC}"
    echo "================================================================================"
    echo ""
    echo "Access URLs:"
    echo "  Frontend:  https://${RMM_DOMAIN}"
    echo "  API:       https://${API_DOMAIN}"
    echo "  Mesh:      https://${MESH_DOMAIN}"
    echo ""
    echo "Admin Credentials:"
    echo "  Username:  ${ADMIN_USERNAME}"
    echo "  Password:  ${ADMIN_PASSWORD}"
    echo ""
    echo "Important Notes:"
    echo "  1. All credentials are stored in: ${SCRIPT_DIR}/.env"
    echo "  2. Change the admin password after first login!"
    echo "  3. Ensure DNS records point to this server:"
    echo "     - ${RMM_DOMAIN}"
    echo "     - ${API_DOMAIN}"
    echo "     - ${MESH_DOMAIN}"
    echo ""
    echo "Useful Commands:"
    echo "  View logs:        ${COMPOSE_CMD} logs -f [service_name]"
    echo "  Restart service:  ${COMPOSE_CMD} restart [service_name]"
    echo "  Stop all:         ${COMPOSE_CMD} down"
    echo "  Start all:        ${COMPOSE_CMD} up -d"
    echo ""
    echo "Service Names: tacticalrmm, celery, celerybeat, postgres, redis, meshcentral, nginx"
    echo "================================================================================"
}

main() {
    clear
    echo "================================================================================"
    echo "                TacticalRMM Docker Deployment Script"
    echo "================================================================================"
    echo ""

    check_root
    check_docker

    echo ""
    read -p "Press Enter to begin installation or Ctrl+C to cancel..."
    echo ""

    generate_passwords
    create_env_file
    setup_ssl

    # Load environment variables
    set -a
    source .env
    set +a

    update_nginx_config
    pull_images
    build_images
    start_services

    print_summary
}

main "$@"
