#!/bin/bash
################################################################################
# TacticalRMM Systemd Services Configuration
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting Systemd Services Configuration ==="

    check_root

    # TacticalRMM API service
    log "Creating TacticalRMM API service..."
    cat > /etc/systemd/system/tacticalrmm.service <<EOF
[Unit]
Description=TacticalRMM API
After=network.target postgresql.service redis-server.service

[Service]
Type=exec
User=tactical
Group=tactical
WorkingDirectory=${INSTALL_DIR}/api/tacticalrmm
Environment="PATH=${INSTALL_DIR}/env/bin"
ExecStart=${INSTALL_DIR}/env/bin/gunicorn tacticalrmm.wsgi:application --bind 127.0.0.1:${GUNICORN_PORT} --workers ${GUNICORN_WORKERS} --timeout ${GUNICORN_TIMEOUT}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Celery service
    log "Creating Celery service..."
    cat > /etc/systemd/system/celery.service <<EOF
[Unit]
Description=TacticalRMM Celery Service
After=network.target redis-server.service postgresql.service

[Service]
Type=exec
User=tactical
Group=tactical
WorkingDirectory=${INSTALL_DIR}/api/tacticalrmm
Environment="PATH=${INSTALL_DIR}/env/bin"
ExecStart=${INSTALL_DIR}/env/bin/celery -A tacticalrmm worker --loglevel=info --logfile=${LOG_DIR}/celery.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Celery beat service
    log "Creating Celery Beat service..."
    cat > /etc/systemd/system/celerybeat.service <<EOF
[Unit]
Description=TacticalRMM Celery Beat Service
After=network.target redis-server.service postgresql.service

[Service]
Type=simple
User=tactical
Group=tactical
WorkingDirectory=${INSTALL_DIR}/api/tacticalrmm
Environment="PATH=${INSTALL_DIR}/env/bin"
ExecStart=${INSTALL_DIR}/env/bin/celery -A tacticalrmm beat --loglevel=info --logfile=${LOG_DIR}/beat.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log "Systemd services created successfully"

    log "=== Systemd Services Configuration Completed ==="
}

main "$@"
