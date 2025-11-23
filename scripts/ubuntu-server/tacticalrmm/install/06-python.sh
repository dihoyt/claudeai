#!/bin/bash
################################################################################
# Python Installation and Dependencies
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting Python Installation ==="

    check_root

    log "Installing Python ${PYTHON_VERSION} and dependencies..."
    # Ubuntu 24.04 ships with Python 3.12 as default
    install_packages \
        python3 \
        python3-venv \
        python3-dev \
        python3-pip \
        build-essential \
        libpq-dev

    # Install libraries required for weasyprint (PDF generation)
    log "Installing weasyprint system dependencies..."
    install_packages \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libgdk-pixbuf2.0-0 \
        libffi-dev \
        shared-mime-info

    log "Python version: $(python3 --version)"
    log "pip version: $(pip3 --version)"

    log "=== Python Installation Completed ==="
}

main "$@"
