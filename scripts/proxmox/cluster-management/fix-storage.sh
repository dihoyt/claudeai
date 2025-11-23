#!/bin/bash

################################################################################
# Proxmox Storage Configuration Recovery Script
#
# Recreates the storage.cfg file with local and local-lvm storage.
# Use this after cluster disband or if storage configuration is lost.
#
# Usage: sudo ./fix-storage.sh
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

################################################################################
# Storage Configuration
################################################################################

backup_existing_config() {
    if [ -f /etc/pve/storage.cfg ]; then
        log "Backing up existing storage configuration..."
        cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup.$(date +%Y%m%d-%H%M%S)
        log "Backup created"
    fi
}

verify_lvm_exists() {
    log "Verifying LVM configuration..."

    # Check if volume group exists
    if ! vgs pve &>/dev/null; then
        error "Volume group 'pve' not found. Cannot configure local-lvm."
    fi

    # Check if thin pool exists
    if ! lvs pve/data &>/dev/null; then
        error "Thin pool 'data' not found in volume group 'pve'."
    fi

    log "LVM configuration verified (vg: pve, pool: data)"
}

create_storage_config() {
    log "Creating storage configuration..."

    cat > /etc/pve/storage.cfg << 'EOF'
dir: local
	path /var/lib/vz
	content iso,vztmpl,backup

lvmthin: local-lvm
	thinpool data
	vgname pve
	content rootdir,images
EOF

    log "Storage configuration created"
}

restart_services() {
    log "Restarting Proxmox services..."

    systemctl restart pvedaemon
    systemctl restart pveproxy

    sleep 2

    log "Services restarted"
}

verify_storage() {
    echo ""
    log "Verifying storage configuration..."
    echo ""

    if pvesm status &>/dev/null; then
        info "Storage status:"
        echo "================================================================================"
        pvesm status
        echo "================================================================================"
        echo ""
        return 0
    else
        error "Storage verification failed"
        return 1
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox Storage Configuration Fix"
    echo "================================================================================"
    echo ""
    echo "This script will recreate /etc/pve/storage.cfg with:"
    echo ""
    echo "  • local      - Directory storage at /var/lib/vz"
    echo "                 (ISO images, templates, backups)"
    echo ""
    echo "  • local-lvm  - LVM-thin storage (vg: pve, pool: data)"
    echo "                 (VM disks, container volumes)"
    echo ""
    echo "================================================================================"
    echo ""

    # Check prerequisites
    check_root

    # Verify LVM exists
    verify_lvm_exists

    # Confirm
    read -p "Do you want to recreate the storage configuration? [Y/n]: " CONFIRM
    echo ""

    if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
        warn "Operation cancelled by user"
        exit 0
    fi

    # Backup existing config if it exists
    backup_existing_config

    # Create new storage config
    create_storage_config

    # Restart services
    restart_services

    # Verify
    verify_storage

    # Done
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Storage Configuration Fixed!${NC}"
    echo "================================================================================"
    echo ""
    echo "Storage 'local' and 'local-lvm' have been configured and are ready to use."
    echo ""
    echo "You can now:"
    echo "  • View storage in Proxmox web UI: Datacenter → Storage"
    echo "  • Check status: pvesm status"
    echo "  • List storage: pvesm list <storage-id>"
    echo ""
    echo "================================================================================"
    echo ""
}

main "$@"