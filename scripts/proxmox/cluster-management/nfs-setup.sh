#!/bin/bash

################################################################################
# Proxmox NFS Storage Setup Script
#
# Adds NFS shares from NAS (10.50.1.100) to Proxmox storage configuration.
#
# NFS Shares:
#   - backups:   10.50.1.100:/volume1/backup
#   - isos:      10.50.1.100:/volume1/isos
#   - scripts:   10.50.1.100:/volume1/scripts
#   - templates: 10.50.1.100:/volume1/templates
#
# Usage: sudo ./nfs-setup.sh
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# NFS Server Configuration
NFS_SERVER="10.50.1.100"

# NFS Share Definitions
# Format: "storage_id|export_path|content_types|description"
declare -a NFS_SHARES=(
    "backups|/volume1/backup|backup,vztmpl|Backup Storage"
    "isos|/volume1/isos|iso|ISO Images"
    "scripts|/volume1/scripts|snippets|Scripts and Snippets"
    "templates|/volume1/templates|vztmpl,backup|VM Templates"
)

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

highlight() {
    echo -e "${CYAN}$1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

################################################################################
# Validation Functions
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

test_nfs_connectivity() {
    log "Testing connectivity to NFS server $NFS_SERVER..."

    if ! ping -c 2 -W 3 "$NFS_SERVER" &>/dev/null; then
        error "Cannot reach NFS server at $NFS_SERVER. Please check network connectivity."
    fi

    log "NFS server is reachable"
}

test_nfs_exports() {
    log "Checking NFS exports on server..."

    if ! showmount -e "$NFS_SERVER" &>/dev/null; then
        error "Cannot query NFS exports from $NFS_SERVER. Make sure NFS is properly configured."
    fi

    echo ""
    highlight "Available NFS exports on $NFS_SERVER:"
    showmount -e "$NFS_SERVER"
    echo ""
}

################################################################################
# Storage Configuration Functions
################################################################################

check_storage_exists() {
    local storage_id=$1

    if pvesm status | grep -q "^$storage_id "; then
        return 0  # Storage exists
    else
        return 1  # Storage doesn't exist
    fi
}

add_nfs_storage() {
    local storage_id=$1
    local export_path=$2
    local content_types=$3
    local description=$4

    if check_storage_exists "$storage_id"; then
        warn "Storage '$storage_id' already exists, skipping..."
        return 0
    fi

    log "Adding NFS storage: $storage_id"
    info "  Server:   $NFS_SERVER"
    info "  Export:   $export_path"
    info "  Content:  $content_types"

    # Add the NFS storage using pvesm
    if pvesm add nfs "$storage_id" \
        --server "$NFS_SERVER" \
        --export "$export_path" \
        --content "$content_types" \
        --options "vers=3"; then
        log "Storage '$storage_id' added successfully"
        return 0
    else
        error "Failed to add storage '$storage_id'"
        return 1
    fi
}

test_mount_storage() {
    local storage_id=$1

    info "Testing mount for $storage_id..."

    # Create a temporary test directory
    local test_dir="/mnt/pve/${storage_id}"

    if [ -d "$test_dir" ]; then
        info "Mount point $test_dir exists and is accessible"
        return 0
    else
        warn "Mount point $test_dir not found"
        return 1
    fi
}

################################################################################
# Main Storage Setup
################################################################################

setup_all_nfs_shares() {
    echo ""
    highlight "Setting up NFS storage..."
    echo "================================================================================"
    echo ""

    local count=0
    local success=0

    for share in "${NFS_SHARES[@]}"; do
        # Parse the share definition
        IFS='|' read -r storage_id export_path content_types description <<< "$share"

        ((count++))
        echo ""
        log "[$count/${#NFS_SHARES[@]}] Setting up: $description"
        echo "--------------------------------------------------------------------------------"

        if add_nfs_storage "$storage_id" "$export_path" "$content_types" "$description"; then
            ((success++))
            sleep 1
            test_mount_storage "$storage_id" || warn "Mount test failed for $storage_id"
        fi
    done

    echo ""
    echo "================================================================================"
    log "Setup complete: $success/${#NFS_SHARES[@]} shares added successfully"
    echo "================================================================================"
    echo ""
}

show_storage_status() {
    echo ""
    highlight "Current Proxmox Storage Status:"
    echo "================================================================================"
    pvesm status
    echo "================================================================================"
    echo ""
}

show_summary() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}NFS Storage Setup Complete!${NC}"
    echo "================================================================================"
    echo ""
    echo "Added NFS shares:"
    echo ""

    for share in "${NFS_SHARES[@]}"; do
        IFS='|' read -r storage_id export_path content_types description <<< "$share"
        echo "  ✓ $storage_id: $NFS_SERVER:$export_path"
        echo "    Content: $content_types"
        echo ""
    done

    echo "================================================================================"
    echo ""
    echo "You can now use these storage locations in the Proxmox web UI:"
    echo ""
    echo "  • Datacenter → Storage → View all configured storage"
    echo "  • When creating VMs, select these storage locations for ISOs, backups, etc."
    echo ""
    echo "To manually mount/unmount storage:"
    echo "  pvesm set <storage-id> --disable 0|1"
    echo ""
    echo "To remove a storage:"
    echo "  pvesm remove <storage-id>"
    echo ""
    echo "================================================================================"
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox NFS Storage Setup Script"
    echo "================================================================================"
    echo ""
    echo "This script will add the following NFS shares to Proxmox:"
    echo ""

    for share in "${NFS_SHARES[@]}"; do
        IFS='|' read -r storage_id export_path content_types description <<< "$share"
        echo "  • $description"
        echo "    ID: $storage_id"
        echo "    Server: $NFS_SERVER:$export_path"
        echo "    Content: $content_types"
        echo ""
    done

    echo "================================================================================"
    echo ""

    # Check prerequisites
    check_root

    # Confirm
    read -p "Do you want to proceed with NFS setup? [Y/n]: " CONFIRM
    echo ""

    if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
        warn "Setup cancelled by user"
        exit 0
    fi

    # Install and verify NFS client
    check_nfs_client

    # Test connectivity
    test_nfs_connectivity
    test_nfs_exports

    # Setup all shares
    setup_all_nfs_shares

    # Show results
    show_storage_status
    show_summary
}

main "$@"
