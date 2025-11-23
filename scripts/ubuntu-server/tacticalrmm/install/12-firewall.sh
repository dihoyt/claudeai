#!/bin/bash
################################################################################
# UFW Firewall Configuration
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting Firewall Configuration ==="

    check_root

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
    log "Enabling firewall..."
    echo "y" | ufw enable

    log "Firewall status:"
    ufw status verbose

    log "=== Firewall Configuration Completed ==="
}

main "$@"
