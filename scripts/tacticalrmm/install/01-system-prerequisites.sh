#!/bin/bash
################################################################################
# System Prerequisites Installation
# Updates system and installs base packages
################################################################################

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    log "=== Starting System Prerequisites Installation ==="

    check_root
    check_ubuntu
    check_resources

    log "Updating system packages..."
    apt-get update || error "Failed to update package lists"

    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || error "Failed to upgrade packages"

    log "Installing base packages..."
    install_packages \
        curl \
        wget \
        git \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        ufw \
        openssl

    # Install QEMU Guest Agent for Proxmox integration
    if [[ "${INSTALL_QEMU_AGENT}" == "true" ]]; then
        log "Installing QEMU Guest Agent for Proxmox..."
        install_packages qemu-guest-agent
        enable_and_start_service qemu-guest-agent
    fi

    log "=== System Prerequisites Installation Completed ==="
}

main "$@"
