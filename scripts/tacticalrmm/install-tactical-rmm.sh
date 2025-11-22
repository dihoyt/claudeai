#!/bin/bash

################################################################################
# TacticalRMM Complete Installation Script
# For Ubuntu 24.04 LTS
# Optimized for Proxmox VMs
#
# This script performs a complete installation of TacticalRMM including:
# - PostgreSQL 16 database (local)
# - Redis with authentication
# - MeshCentral for remote access
# - TacticalRMM backend (Django/Python 3.12)
# - TacticalRMM frontend (Vue.js)
# - Nginx reverse proxy
# - Systemd service files
#
# Recommended Resources: 8GB RAM, 6 CPU cores, 30GB storage
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Configuration Variables
################################################################################

DOMAIN="tacticalrmm.hoyt.local"
API_DOMAIN="api.${DOMAIN}"
MESH_DOMAIN="mesh.${DOMAIN}"
RMM_DOMAIN="rmm.${DOMAIN}"

# Generate secure random passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
ADMIN_PASSWORD=$(openssl rand -base64 24)
MESH_TOKEN=$(openssl rand -hex 32)

# Log file
LOG_FILE="/var/log/tacticalrmm-install.log"

################################################################################
# Helper Functions
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
# Installation Functions
################################################################################

update_system() {
    log "Updating system packages..."

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    apt-get install -y \
        curl \
        wget \
        git \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        ufw

    # Install QEMU Guest Agent for Proxmox integration
    log "Installing QEMU Guest Agent for Proxmox..."
    apt-get install -y qemu-guest-agent
    systemctl enable qemu-guest-agent
    systemctl start qemu-guest-agent

    log "System update completed"
}

install_postgresql() {
    log "Installing PostgreSQL..."

    apt-get install -y postgresql postgresql-contrib

    systemctl enable postgresql
    systemctl start postgresql

    # Create database and user
    log "Creating TacticalRMM database..."
    sudo -u postgres psql <<EOF
CREATE DATABASE tacticalrmm;
CREATE USER tacticalrmm WITH PASSWORD '${POSTGRES_PASSWORD}';
ALTER ROLE tacticalrmm SET client_encoding TO 'utf8';
ALTER ROLE tacticalrmm SET default_transaction_isolation TO 'read committed';
ALTER ROLE tacticalrmm SET timezone TO 'UTC';
ALTER DATABASE tacticalrmm OWNER TO tacticalrmm;
GRANT ALL PRIVILEGES ON DATABASE tacticalrmm TO tacticalrmm;
\c tacticalrmm
GRANT ALL ON SCHEMA public TO tacticalrmm;
\q
EOF

    # Configure PostgreSQL for local connections
    log "Configuring PostgreSQL..."
    # Detect PostgreSQL version dynamically
    PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
    PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

    if [ ! -f "$PG_HBA" ]; then
        error "PostgreSQL configuration file not found at $PG_HBA"
    fi

    if ! grep -q "tacticalrmm" "$PG_HBA"; then
        echo "local   tacticalrmm     tacticalrmm                             md5" >> "$PG_HBA"
    fi

    systemctl restart postgresql
    log "PostgreSQL installation completed"
}

install_redis() {
    log "Installing Redis..."

    apt-get install -y redis-server

    # Configure Redis with password
    log "Configuring Redis..."
    # Find Redis config file (path may vary)
    REDIS_CONF=$(find /etc -name redis.conf 2>/dev/null | head -1)

    if [ -z "$REDIS_CONF" ]; then
        error "Redis configuration file not found"
    fi

    log "Using Redis config: $REDIS_CONF"

    # Set password
    sed -i "s/^# requirepass .*/requirepass ${REDIS_PASSWORD}/" "$REDIS_CONF"
    # Ensure it's added even if the commented line doesn't exist
    if ! grep -q "^requirepass" "$REDIS_CONF"; then
        echo "requirepass ${REDIS_PASSWORD}" >> "$REDIS_CONF"
    fi

    # Bind to localhost only
    sed -i 's/^bind 127.0.0.1 ::1/bind 127.0.0.1/' "$REDIS_CONF"

    systemctl enable redis-server
    systemctl restart redis-server
    log "Redis installation completed"
}

install_nginx() {
    log "Installing Nginx..."

    apt-get install -y nginx

    systemctl enable nginx
    systemctl stop nginx  # Stop until we configure it

    log "Nginx installed"
}

install_nodejs() {
    log "Installing Node.js 20.x..."

    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs

    npm install -g npm@latest

    log "Node.js $(node --version) and npm $(npm --version) installed"
}

install_python() {
    log "Installing Python 3.12 and dependencies..."

    # Ubuntu 24.04 ships with Python 3.12 as default
    apt-get install -y python3 python3-venv python3-dev python3-pip
    apt-get install -y build-essential libpq-dev

    # Install libraries required for weasyprint (PDF generation)
    log "Installing weasyprint system dependencies..."
    apt-get install -y \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libgdk-pixbuf2.0-0 \
        libffi-dev \
        shared-mime-info

    log "Python version: $(python3 --version)"
}

install_meshcentral() {
    log "Installing MeshCentral..."

    # Create meshcentral user
    if ! id -u meshcentral &>/dev/null; then
        useradd -m -s /bin/bash meshcentral
    fi

    # Create directories
    mkdir -p /meshcentral/meshcentral-data
    mkdir -p /meshcentral/meshcentral-files
    mkdir -p /meshcentral/meshcentral-backup

    cd /meshcentral

    # Install MeshCentral
    npm install meshcentral@latest

    # Create MeshCentral config
    log "Configuring MeshCentral..."
    cat > /meshcentral/meshcentral-data/config.json <<EOF
{
  "settings": {
    "Cert": "${MESH_DOMAIN}",
    "WANonly": true,
    "Minify": 1,
    "Port": 4430,
    "AliasPort": 443,
    "RedirPort": 800,
    "TlsOffload": "127.0.0.1",
    "trustedProxy": "127.0.0.1"
  },
  "domains": {
    "": {
      "Title": "TacticalRMM MeshCentral",
      "Title2": "Remote Management",
      "NewAccounts": false,
      "CertUrl": "https://${API_DOMAIN}",
      "GeoLocation": true,
      "CookieIpCheck": false,
      "mstsc": true
    }
  }
}
EOF

    # Create systemd service for MeshCentral
    log "Creating MeshCentral systemd service..."
    cat > /etc/systemd/system/meshcentral.service <<EOF
[Unit]
Description=MeshCentral Server
After=network.target

[Service]
Type=simple
User=meshcentral
Group=meshcentral
ExecStart=/usr/bin/node /meshcentral/node_modules/meshcentral
WorkingDirectory=/meshcentral
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    chown -R meshcentral:meshcentral /meshcentral

    systemctl daemon-reload
    systemctl enable meshcentral

    log "MeshCentral installation completed"
}

install_tacticalrmm() {
    log "Installing TacticalRMM..."

    # Create tactical user
    if ! id -u tactical &>/dev/null; then
        useradd -m -s /bin/bash tactical
    fi

    # Create directories
    mkdir -p /rmm
    mkdir -p /var/log/celery
    chown -R tactical:tactical /var/log/celery

    # Clone TacticalRMM repository as tactical user
    log "Cloning TacticalRMM repository..."
    cd /rmm
    chown tactical:tactical /rmm

    # Add safe directory for git
    git config --global --add safe.directory /rmm

    # Clone as tactical user to avoid ownership issues
    sudo -u tactical git clone https://github.com/amidaware/tacticalrmm.git .

    # Ensure ownership
    chown -R tactical:tactical /rmm

    # Create Python virtual environment
    log "Setting up Python virtual environment..."
    cd /rmm
    sudo -u tactical python3 -m venv env

    # Install Python dependencies
    log "Installing Python dependencies (this may take several minutes)..."
    cd /rmm/api/tacticalrmm

    sudo -u tactical /bin/bash <<EOF
source /rmm/env/bin/activate
pip install --upgrade pip
pip install wheel setuptools
pip install gunicorn
pip install -r requirements.txt
deactivate
EOF

    # Create Django settings
    log "Configuring Django settings..."

    # Generate Django secret key
    DJANGO_SECRET=$(sudo -u tactical /rmm/env/bin/python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')

    cat > /rmm/api/tacticalrmm/tacticalrmm/local_settings.py <<EOF
import os

DEBUG = False
ALLOWED_HOSTS = ['${API_DOMAIN}', 'localhost', '127.0.0.1']

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'tacticalrmm',
        'USER': 'tacticalrmm',
        'PASSWORD': '${POSTGRES_PASSWORD}',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

REDIS_HOST = 'localhost'
REDIS_PORT = 6379
REDIS_PASSWORD = '${REDIS_PASSWORD}'

MESH_USERNAME = 'tactical'
MESH_SITE = 'https://${MESH_DOMAIN}'
MESH_TOKEN = '${MESH_TOKEN}'

SECRET_KEY = '${DJANGO_SECRET}'

CORS_ORIGIN_WHITELIST = [
    'https://${RMM_DOMAIN}'
]

ADMIN_URL = 'admin/'

# Celery settings
CELERY_BROKER_URL = f'redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/0'
CELERY_RESULT_BACKEND = f'redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/0'
EOF

    chown tactical:tactical /rmm/api/tacticalrmm/tacticalrmm/local_settings.py

    # Run Django migrations
    log "Running database migrations..."
    sudo -u tactical /bin/bash <<EOF
cd /rmm/api/tacticalrmm
source /rmm/env/bin/activate
python manage.py migrate
deactivate
EOF

    # Collect static files
    log "Collecting static files..."
    sudo -u tactical /bin/bash <<EOF
cd /rmm/api/tacticalrmm
source /rmm/env/bin/activate
python manage.py collectstatic --noinput
deactivate
EOF

    # Create superuser
    log "Creating Django superuser..."
    sudo -u tactical /bin/bash <<EOF
cd /rmm/api/tacticalrmm
source /rmm/env/bin/activate
python manage.py shell <<PYEOF
from accounts.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@${DOMAIN}', '${ADMIN_PASSWORD}')
PYEOF
deactivate
EOF

    # Set permissions
    chown -R tactical:tactical /rmm
    mkdir -p /rmm/api/tacticalrmm/tacticalrmm/private
    chown -R tactical:www-data /rmm/api/tacticalrmm/tacticalrmm/private
    chmod 750 /rmm/api/tacticalrmm/tacticalrmm/private

    log "TacticalRMM backend installation completed"
}

create_systemd_services() {
    log "Creating systemd services for TacticalRMM..."

    # TacticalRMM API service
    cat > /etc/systemd/system/tacticalrmm.service <<EOF
[Unit]
Description=TacticalRMM API
After=network.target postgresql.service redis-server.service

[Service]
Type=exec
User=tactical
Group=tactical
WorkingDirectory=/rmm/api/tacticalrmm
Environment="PATH=/rmm/env/bin"
ExecStart=/rmm/env/bin/gunicorn tacticalrmm.wsgi:application --bind 127.0.0.1:8000 --workers 4 --timeout 300
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Celery service
    cat > /etc/systemd/system/celery.service <<EOF
[Unit]
Description=TacticalRMM Celery Service
After=network.target redis-server.service postgresql.service

[Service]
Type=exec
User=tactical
Group=tactical
WorkingDirectory=/rmm/api/tacticalrmm
Environment="PATH=/rmm/env/bin"
ExecStart=/rmm/env/bin/celery -A tacticalrmm worker --loglevel=info --logfile=/var/log/celery/celery.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Celery beat service
    cat > /etc/systemd/system/celerybeat.service <<EOF
[Unit]
Description=TacticalRMM Celery Beat Service
After=network.target redis-server.service postgresql.service

[Service]
Type=simple
User=tactical
Group=tactical
WorkingDirectory=/rmm/api/tacticalrmm
Environment="PATH=/rmm/env/bin"
ExecStart=/rmm/env/bin/celery -A tacticalrmm beat --loglevel=info --logfile=/var/log/celery/beat.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log "Systemd services created"
}

install_frontend() {
    log "Installing TacticalRMM frontend..."

    cd /rmm/web

    # Create environment file
    cat > .env <<EOF
VUE_APP_API_URL=https://${API_DOMAIN}
VUE_APP_WS_URL=wss://${API_DOMAIN}
EOF

    # Install dependencies and build
    log "Building frontend (this may take 5-10 minutes)..."
    npm install
    npm run build

    # Create web directory
    mkdir -p /var/www/rmm
    cp -r dist/* /var/www/rmm/
    chown -R www-data:www-data /var/www/rmm

    log "Frontend installation completed"
}

configure_nginx() {
    log "Configuring Nginx..."

    # Create directories for certificates
    mkdir -p /etc/nginx/ssl

    # API configuration
    cat > /etc/nginx/sites-available/rmm-api.conf <<'EOF'
upstream tacticalrmm {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name api.tacticalrmm.hoyt.local;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.tacticalrmm.hoyt.local;

    ssl_certificate /etc/nginx/ssl/wildcard.crt;
    ssl_certificate_key /etc/nginx/ssl/wildcard.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    client_max_body_size 300M;

    location /static/ {
        alias /rmm/api/tacticalrmm/static/;
    }

    location /private/ {
        internal;
        alias /rmm/api/tacticalrmm/tacticalrmm/private/;
    }

    location / {
        proxy_pass http://tacticalrmm;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

    # Frontend configuration
    cat > /etc/nginx/sites-available/rmm-frontend.conf <<'EOF'
server {
    listen 80;
    server_name rmm.tacticalrmm.hoyt.local;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name rmm.tacticalrmm.hoyt.local;

    ssl_certificate /etc/nginx/ssl/wildcard.crt;
    ssl_certificate_key /etc/nginx/ssl/wildcard.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root /var/www/rmm;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # MeshCentral configuration
    cat > /etc/nginx/sites-available/rmm-meshcentral.conf <<'EOF'
upstream meshcentral {
    server 127.0.0.1:4430;
}

server {
    listen 80;
    server_name mesh.tacticalrmm.hoyt.local;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name mesh.tacticalrmm.hoyt.local;

    ssl_certificate /etc/nginx/ssl/wildcard.crt;
    ssl_certificate_key /etc/nginx/ssl/wildcard.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://meshcentral;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_read_timeout 86400;
    }
}
EOF

    # Enable sites
    ln -sf /etc/nginx/sites-available/rmm-api.conf /etc/nginx/sites-enabled/
    ln -sf /etc/nginx/sites-available/rmm-frontend.conf /etc/nginx/sites-enabled/
    ln -sf /etc/nginx/sites-available/rmm-meshcentral.conf /etc/nginx/sites-enabled/

    # Remove default site
    rm -f /etc/nginx/sites-enabled/default

    log "Nginx configuration completed"
}

configure_firewall() {
    log "Configuring UFW firewall..."

    # Set defaults
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH
    ufw allow 22/tcp comment 'SSH'

    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'

    # Enable firewall
    echo "y" | ufw enable

    ufw status
    log "Firewall configured"
}

start_services() {
    log "Starting services..."

    # Start MeshCentral
    systemctl start meshcentral
    sleep 2

    # Start TacticalRMM services
    systemctl start tacticalrmm
    sleep 2
    systemctl start celery
    systemctl start celerybeat

    sleep 5

    # Check service status
    local services=("postgresql" "redis-server" "meshcentral" "tacticalrmm" "celery" "celerybeat")

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "✓ $service is running"
        else
            warn "✗ $service failed to start"
        fi
    done
}

save_credentials() {
    log "Saving credentials..."

    CREDS_FILE="/root/tacticalrmm-credentials.txt"

    cat > "$CREDS_FILE" <<EOF
================================================================================
TacticalRMM Installation Credentials
Generated: $(date)
================================================================================

WEB INTERFACE:
--------------
Frontend URL: https://${RMM_DOMAIN}
API URL:      https://${API_DOMAIN}
Mesh URL:     https://${MESH_DOMAIN}

Admin Username: admin
Admin Password: ${ADMIN_PASSWORD}

DATABASE:
---------
PostgreSQL Database: tacticalrmm
PostgreSQL User:     tacticalrmm
PostgreSQL Password: ${POSTGRES_PASSWORD}

REDIS:
------
Redis Password: ${REDIS_PASSWORD}

MESHCENTRAL:
------------
Mesh Token: ${MESH_TOKEN}

IMPORTANT NOTES:
----------------
1. SSL certificates need to be in place at:
   /etc/nginx/ssl/wildcard.crt
   /etc/nginx/ssl/wildcard.key

   Copy your *.hoyt.local wildcard certificate from step-ca:
   cp /path/to/wildcard.crt /etc/nginx/ssl/wildcard.crt
   cp /path/to/wildcard.key /etc/nginx/ssl/wildcard.key
   chmod 644 /etc/nginx/ssl/wildcard.crt
   chmod 600 /etc/nginx/ssl/wildcard.key

2. After installing certificates, start nginx:
   systemctl start nginx

3. Change the admin password after first login!

4. DNS must be configured for:
   - tacticalrmm.hoyt.local
   - api.tacticalrmm.hoyt.local
   - rmm.tacticalrmm.hoyt.local
   - mesh.tacticalrmm.hoyt.local

5. This file contains sensitive information - protect it!
   chmod 600 /root/tacticalrmm-credentials.txt

TROUBLESHOOTING:
----------------
View service logs:
  journalctl -xeu tacticalrmm
  journalctl -xeu celery
  journalctl -xeu celerybeat
  journalctl -xeu meshcentral
  journalctl -xeu nginx

View installation log:
  cat ${LOG_FILE}

================================================================================
EOF

    chmod 600 "$CREDS_FILE"

    log "Credentials saved to: $CREDS_FILE"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    TacticalRMM Installation Script"
    echo "                         Ubuntu 24.04 LTS"
    echo "================================================================================"
    echo ""
    echo "Domain Configuration:"
    echo "  Domain:       ${DOMAIN}"
    echo "  API Domain:   ${API_DOMAIN}"
    echo "  Mesh Domain:  ${MESH_DOMAIN}"
    echo "  RMM Domain:   ${RMM_DOMAIN}"
    echo ""
    echo "This script will install:"
    echo "  ✓ PostgreSQL 16 database"
    echo "  ✓ Redis with authentication"
    echo "  ✓ MeshCentral remote access server"
    echo "  ✓ TacticalRMM backend (Django/Python 3.12)"
    echo "  ✓ TacticalRMM frontend (Vue.js)"
    echo "  ✓ Nginx reverse proxy"
    echo "  ✓ UFW firewall configuration"
    echo "  ✓ QEMU Guest Agent (for Proxmox)"
    echo ""
    echo "Installation log: ${LOG_FILE}"
    echo ""
    echo "================================================================================"
    echo ""

    read -p "Press Enter to continue or Ctrl+C to cancel..."

    log "Starting TacticalRMM installation..."

    # Pre-flight checks
    check_root
    check_ubuntu
    check_resources

    # Installation steps
    update_system
    install_postgresql
    install_redis
    install_nginx
    install_nodejs
    install_python
    install_meshcentral
    install_tacticalrmm
    create_systemd_services
    install_frontend
    configure_nginx
    configure_firewall
    save_credentials
    start_services

    echo ""
    echo "================================================================================"
    echo "                    Installation Complete!"
    echo "================================================================================"
    echo ""
    echo -e "${GREEN}✓${NC} TacticalRMM has been installed successfully!"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Copy your wildcard SSL certificate:"
    echo -e "   ${YELLOW}cp /path/to/wildcard.crt /etc/nginx/ssl/wildcard.crt${NC}"
    echo -e "   ${YELLOW}cp /path/to/wildcard.key /etc/nginx/ssl/wildcard.key${NC}"
    echo -e "   ${YELLOW}chmod 644 /etc/nginx/ssl/wildcard.crt${NC}"
    echo -e "   ${YELLOW}chmod 600 /etc/nginx/ssl/wildcard.key${NC}"
    echo ""
    echo "2. Start nginx:"
    echo -e "   ${YELLOW}systemctl start nginx${NC}"
    echo ""
    echo "3. Access TacticalRMM:"
    echo -e "   ${GREEN}https://${RMM_DOMAIN}${NC}"
    echo ""
    echo "4. Review credentials:"
    echo -e "   ${YELLOW}cat /root/tacticalrmm-credentials.txt${NC}"
    echo ""
    echo "5. Verify all services:"
    echo -e "   ${YELLOW}systemctl status tacticalrmm celery celerybeat meshcentral nginx${NC}"
    echo ""
    echo "Installation log: ${LOG_FILE}"
    echo "================================================================================"
}

main "$@"
