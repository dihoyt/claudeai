#!/bin/bash
################################################################################
# Node.js Installation
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting Node.js Installation ==="

    check_root

    log "Installing Node.js ${NODEJS_VERSION}.x..."
    curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | bash - || error "Failed to add Node.js repository"

    install_packages nodejs

    log "Updating npm to latest version..."
    npm install -g npm@latest || warn "Failed to update npm"

    log "Node.js version: $(node --version)"
    log "npm version: $(npm --version)"

    log "=== Node.js Installation Completed ==="
}

main "$@"
