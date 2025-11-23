#!/bin/bash

################################################################################
# Proxmox NFS Storage Setup Script
#
# Adds 4 NFS shares from NAS (10.50.1.100) to Proxmox storage configuration.
# Also creates symlink /scripts -> /mnt/pve/scripts for easy access.
#
# NFS Shares:
#   - backups:  10.50.1.100:/volume1/backups
#   - scripts:  10.50.1.100:/volume1/scripts
#   - images:   10.50.1.100:/volume1/images
#   - docker:   10.50.1.100:/volume1/docker
#
# Usage: sudo ./add-nfs-storage.sh
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# NFS Server Configuration
NFS_SERVER="10.50.1.100"

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
# NFS Setup Functions
################################################################################

check_nfs_client() {
    log "Checking NFS client installation..."

    if ! command -v mount.nfs &> /dev/null; then
        warn "NFS client not installed. Installing..."
        apt-get update -qq
        apt-get install -y nfs-common
        log "NFS client installed"
    else
        log "NFS client already installed"
    fi
}

test_nfs_server() {
    log "Testing connectivity to NFS server $NFS_SERVER..."

    if ! ping -c 2 -W 3 "$NFS_SERVER" &>/dev/null; then
        error "Cannot reach NFS server at $NFS_SERVER. Please check network connectivity."
    fi

    log "NFS server is reachable"
}

backup_storage_config() {
    if [ -f /etc/pve/storage.cfg ]; then
        log "Backing up storage configuration..."
        cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup.$(date +%Y%m%d-%H%M%S)
        log "Backup created"
    fi
}

add_nfs_storage() {
    log "Adding NFS storage configuration to /etc/pve/storage.cfg..."

    # Check if storage.cfg exists, if not create it
    if [ ! -f /etc/pve/storage.cfg ]; then
        touch /etc/pve/storage.cfg
    fi

    # Append NFS configurations
    cat >> /etc/pve/storage.cfg << 'EOF'

nfs: backups
	export /volume1/backups
	path /mnt/pve/backups
	server 10.50.1.100
	content backup,vztmpl
	options vers=3

nfs: scripts
	export /volume1/scripts
	path /mnt/pve/scripts
	server 10.50.1.100
	content snippets
	options vers=3

nfs: images
	export /volume1/images
	path /mnt/pve/images
	server 10.50.1.100
	content iso,vztmpl,images
	options vers=3

nfs: docker
	export /volume1/docker
	path /mnt/pve/docker
	server 10.50.1.100
	content rootdir,images
	options vers=3
EOF

    log "NFS storage configuration added"
}

create_scripts_symlink() {
    log "Creating symlink /scripts -> /mnt/pve/scripts..."

    # Remove existing symlink or file if it exists
    if [ -L /scripts ] || [ -f /scripts ]; then
        warn "Removing existing /scripts"
        rm -f /scripts
    elif [ -d /scripts ] && [ ! -L /scripts ]; then
        warn "/scripts exists as a directory, backing it up..."
        mv /scripts /scripts.backup.$(date +%Y%m%d-%H%M%S)
    fi

    # Create the symlink
    ln -s /mnt/pve/scripts /scripts

    if [ -L /scripts ]; then
        log "Symlink created: /scripts -> /mnt/pve/scripts"
    else
        error "Failed to create symlink"
    fi
}

restart_services() {
    log "Restarting Proxmox services..."

    systemctl restart pvedaemon
    systemctl restart pveproxy

    sleep 3

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
        warn "Storage verification failed - mounts may take a moment to appear"
        return 1
    fi
}

verify_symlink() {
    echo ""
    log "Verifying symlink..."

    if [ -L /scripts ] && [ -d /scripts ]; then
        info "Symlink verified:"
        ls -la /scripts
        echo ""
        return 0
    else
        warn "Symlink verification failed"
        return 1
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox NFS Storage Setup"
    echo "================================================================================"
    echo ""
    echo "This script will add 4 NFS shares from $NFS_SERVER:"
    echo ""
    echo "  • backups   - /volume1/backups  (backups, templates)"
    echo "  • scripts   - /volume1/scripts  (snippets)"
    echo "  • images    - /volume1/images   (ISOs, disk images, templates)"
    echo "  • docker    - /volume1/docker   (containers, VM disks)"
    echo ""
    echo "It will also create a symlink: /scripts -> /mnt/pve/scripts"
    echo ""
    echo "================================================================================"
    echo ""

    # Check prerequisites
    check_root

    # Confirm
    read -p "Do you want to proceed with NFS storage setup? [Y/n]: " CONFIRM
    echo ""

    if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
        warn "Setup cancelled by user"
        exit 0
    fi

    # Install NFS client if needed
    check_nfs_client

    # Test NFS server connectivity
    test_nfs_server

    # Backup existing config
    backup_storage_config

    # Add NFS storage
    add_nfs_storage

    # Restart services to mount NFS shares
    restart_services

    # Wait a moment for mounts to complete
    log "Waiting for NFS shares to mount..."
    sleep 5

    # Create symlink
    create_scripts_symlink

    # Verify
    verify_storage
    verify_symlink

    # Done
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}NFS Storage Setup Complete!${NC}"
    echo "================================================================================"
    echo ""
    echo "Added NFS storage:"
    echo "  ✓ backups  -> $NFS_SERVER:/volume1/backups"
    echo "  ✓ scripts  -> $NFS_SERVER:/volume1/scripts"
    echo "  ✓ images   -> $NFS_SERVER:/volume1/images"
    echo "  ✓ docker   -> $NFS_SERVER:/volume1/docker"
    echo ""
    echo "Created symlink:"
    echo "  ✓ /scripts -> /mnt/pve/scripts"
    echo ""
    echo "You can now:"
    echo "  • View storage in Proxmox web UI: Datacenter → Storage"
    echo "  • Access scripts directly: cd /scripts"
    echo "  • Check storage status: pvesm status"
    echo ""
    echo "================================================================================"
    echo ""
}

main "$@"
