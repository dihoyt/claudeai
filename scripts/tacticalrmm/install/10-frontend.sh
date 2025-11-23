#!/bin/bash
################################################################################
# TacticalRMM Frontend Installation
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting TacticalRMM Frontend Installation ==="

    check_root

    cd "${INSTALL_DIR}/web"

    # Create environment file
    log "Creating frontend environment configuration..."
    cat > .env <<EOF
VUE_APP_API_URL=https://${API_DOMAIN}
VUE_APP_WS_URL=wss://${API_DOMAIN}
EOF

    # Install dependencies and build
    log "Installing npm dependencies..."
    npm install || error "Failed to install npm dependencies"

    log "Building frontend (this may take 5-10 minutes)..."
    npm run build || error "Failed to build frontend"

    # Create web directory
    log "Deploying frontend to ${WEB_ROOT}..."
    create_directory "${WEB_ROOT}" "www-data" "www-data" "755"

    cp -r dist/* "${WEB_ROOT}/" || error "Failed to copy frontend files"
    chown -R www-data:www-data "${WEB_ROOT}"

    log "=== TacticalRMM Frontend Installation Completed ==="
}

main "$@"
