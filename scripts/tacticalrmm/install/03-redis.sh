#!/bin/bash
################################################################################
# Redis Installation and Configuration
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting Redis Installation ==="

    check_root

    log "Installing Redis..."
    install_packages redis-server

    # Configure Redis with password
    log "Configuring Redis..."
    REDIS_CONF=$(find /etc -name redis.conf 2>/dev/null | head -1)

    if [[ -z "$REDIS_CONF" ]]; then
        error "Redis configuration file not found"
    fi

    log "Using Redis config: $REDIS_CONF"
    backup_file "$REDIS_CONF"

    # Set password
    sed -i "s/^# requirepass .*/requirepass ${REDIS_PASSWORD}/" "$REDIS_CONF"

    # Ensure it's added even if the commented line doesn't exist
    if ! grep -q "^requirepass" "$REDIS_CONF"; then
        echo "requirepass ${REDIS_PASSWORD}" >> "$REDIS_CONF"
    fi

    # Bind to localhost only for security
    sed -i 's/^bind 127.0.0.1 ::1/bind 127.0.0.1/' "$REDIS_CONF"

    enable_and_start_service redis-server

    log "=== Redis Installation Completed ==="
}

main "$@"
