#!/bin/bash
################################################################################
# TacticalRMM Backend Installation
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting TacticalRMM Backend Installation ==="

    check_root

    # Create tactical user
    if ! id -u tactical &>/dev/null; then
        log "Creating tactical user..."
        useradd -m -s /bin/bash tactical
    fi

    # Create directories
    log "Creating TacticalRMM directories..."
    create_directory "${INSTALL_DIR}" "tactical" "tactical" "755"
    create_directory "${LOG_DIR}" "tactical" "tactical" "755"

    # Clone TacticalRMM repository
    log "Cloning TacticalRMM repository..."
    cd "${INSTALL_DIR}"

    # Add safe directory for git
    git config --global --add safe.directory "${INSTALL_DIR}"

    # Clone as tactical user to avoid ownership issues
    if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
        sudo -u tactical git clone https://github.com/amidaware/tacticalrmm.git . || error "Failed to clone TacticalRMM repository"
    else
        log "Repository already cloned, pulling latest changes..."
        sudo -u tactical git pull || warn "Failed to pull latest changes"
    fi

    # Ensure ownership
    chown -R tactical:tactical "${INSTALL_DIR}"

    # Create Python virtual environment
    log "Setting up Python virtual environment..."
    if [[ ! -d "${INSTALL_DIR}/env" ]]; then
        sudo -u tactical python3 -m venv "${INSTALL_DIR}/env" || error "Failed to create virtual environment"
    fi

    # Install Python dependencies
    log "Installing Python dependencies (this may take several minutes)..."
    cd "${INSTALL_DIR}/api/tacticalrmm"

    sudo -u tactical /bin/bash <<EOF
set -e
source ${INSTALL_DIR}/env/bin/activate
pip install --upgrade pip
pip install wheel setuptools
pip install gunicorn
pip install -r requirements.txt
deactivate
EOF

    if [[ $? -ne 0 ]]; then
        error "Failed to install Python dependencies"
    fi

    # Verify gunicorn installation
    log "Verifying gunicorn installation..."
    if [[ ! -f "${INSTALL_DIR}/env/bin/gunicorn" ]]; then
        error "Gunicorn binary not found at ${INSTALL_DIR}/env/bin/gunicorn"
    fi

    # Test gunicorn execution
    log "Testing gunicorn execution..."
    if ! sudo -u tactical "${INSTALL_DIR}/env/bin/gunicorn" --version &>/dev/null; then
        error "Gunicorn cannot be executed by tactical user"
    fi

    log "Gunicorn installed and verified successfully"

    # Create Django settings
    log "Configuring Django settings..."
    cat > "${INSTALL_DIR}/api/tacticalrmm/tacticalrmm/local_settings.py" <<EOF
import os

DEBUG = False
ALLOWED_HOSTS = ['${API_DOMAIN}', 'localhost', '127.0.0.1']

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': '${POSTGRES_DB}',
        'USER': '${POSTGRES_USER}',
        'PASSWORD': '${POSTGRES_PASSWORD}',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

REDIS_HOST = 'localhost'
REDIS_PORT = 6379
REDIS_PASSWORD = '${REDIS_PASSWORD}'

MESH_USERNAME = '${MESH_USER}'
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

    chown tactical:tactical "${INSTALL_DIR}/api/tacticalrmm/tacticalrmm/local_settings.py"

    # Run Django migrations
    log "Running database migrations..."
    sudo -u tactical /bin/bash <<EOF
cd ${INSTALL_DIR}/api/tacticalrmm
source ${INSTALL_DIR}/env/bin/activate
python manage.py migrate
deactivate
EOF

    if [[ $? -ne 0 ]]; then
        error "Failed to run database migrations"
    fi

    # Collect static files
    log "Collecting static files..."
    sudo -u tactical /bin/bash <<EOF
cd ${INSTALL_DIR}/api/tacticalrmm
source ${INSTALL_DIR}/env/bin/activate
python manage.py collectstatic --noinput
deactivate
EOF

    if [[ $? -ne 0 ]]; then
        error "Failed to collect static files"
    fi

    # Create superuser
    log "Creating Django superuser..."
    sudo -u tactical /bin/bash <<EOF
cd ${INSTALL_DIR}/api/tacticalrmm
source ${INSTALL_DIR}/env/bin/activate
python manage.py shell <<PYEOF
from accounts.models import User
if not User.objects.filter(username='${ADMIN_USERNAME}').exists():
    User.objects.create_superuser('${ADMIN_USERNAME}', '${ADMIN_EMAIL}', '${ADMIN_PASSWORD}')
    print('Superuser created successfully')
else:
    print('Superuser already exists')
PYEOF
deactivate
EOF

    # Set permissions
    log "Setting file permissions..."
    chown -R tactical:tactical "${INSTALL_DIR}"
    create_directory "${INSTALL_DIR}/api/tacticalrmm/tacticalrmm/private" "tactical" "www-data" "750"

    log "=== TacticalRMM Backend Installation Completed ==="
}

main "$@"
