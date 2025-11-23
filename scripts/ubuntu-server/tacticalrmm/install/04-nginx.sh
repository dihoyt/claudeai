#!/bin/bash
################################################################################
# Nginx Installation (configuration done separately)
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting Nginx Installation ==="

    check_root

    log "Installing Nginx..."
    install_packages nginx

    systemctl enable nginx || warn "Failed to enable nginx"
    systemctl stop nginx  # Stop until we configure it

    # Create SSL directory
    create_directory "/etc/nginx/ssl" "root" "root" "755"

    log "=== Nginx Installation Completed ==="
    info "Nginx will be configured and started in a later step"
}

main "$@"
