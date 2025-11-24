#!/bin/bash
################################################################################
# NFS Mount Setup Script
#
# This script:
# 1. Prompts to add NFS mounts to /etc/fstab
# 2. Checks if entries already exist before adding
# 3. Creates mount point directories if needed
# 4. Mounts the NFS shares
# 5. Logs all actions
#
# Usage: sudo bash setup-nfs-mounts.sh
################################################################################

set -e

# Configuration
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/nfs-mount-setup.log"
FSTAB_FILE="/etc/fstab"
FSTAB_BACKUP="/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"

# NFS Server
NFS_SERVER="10.50.1.100"

# Define NFS mounts (source:mountpoint:options)
declare -a NFS_MOUNTS=(
    "10.50.1.100:/volume1/public:/volume1/public:nfs:auto,nofail,noatime,nolock,intr,tcp,actimeo=1800:0:0"
    "10.50.1.100:/volume1/private:/volume1/private:nfs:auto,nofail,noatime,nolock,intr,tcp,actimeo=1800:0:0"
    "10.50.1.100:/volume1/backups:/volume1/backups:nfs:auto,nofail,noatime,nolock,intr,tcp,actimeo=1800:0:0"
    "10.50.1.100:/volume1/docker:/volume1/docker:nfs:auto,nofail,noatime,nolock,intr,tcp,actimeo=1800:0:0"
)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################

log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
}

print_log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE"
    exit 1
}

success() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

warn() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

info() {
    echo -e "${CYAN}$1${NC}"
}

################################################################################
# Helper Functions
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_nfs_client() {
    print_log "Checking for NFS client installation"

    if command -v mount.nfs &> /dev/null || command -v mount.nfs4 &> /dev/null; then
        success "NFS client is installed"
        return 0
    else
        warn "NFS client is not installed"
        info "Installing NFS client..."

        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            apt-get install -y nfs-common
        elif command -v yum &> /dev/null; then
            yum install -y nfs-utils
        elif command -v dnf &> /dev/null; then
            dnf install -y nfs-utils
        else
            error "Cannot install NFS client. Please install manually."
        fi

        success "NFS client installed"
    fi
}

check_nfs_server_reachable() {
    local server="$1"

    print_log "Checking if NFS server $server is reachable"

    if ping -c 1 -W 2 "$server" &> /dev/null; then
        success "NFS server $server is reachable"
        return 0
    else
        warn "NFS server $server is not reachable (this is OK if server is down temporarily)"
        return 1
    fi
}

backup_fstab() {
    print_log "Backing up /etc/fstab to $FSTAB_BACKUP"
    cp "$FSTAB_FILE" "$FSTAB_BACKUP" || error "Failed to backup fstab"
    success "Backed up fstab successfully"
}

is_mount_in_fstab() {
    local source="$1"
    local mountpoint="$2"

    # Check if either the source or mountpoint already exists in fstab
    if grep -q "^$source[[:space:]]" "$FSTAB_FILE" || \
       grep -q "[[:space:]]$mountpoint[[:space:]]" "$FSTAB_FILE"; then
        return 0  # Found
    else
        return 1  # Not found
    fi
}

create_mount_point() {
    local mountpoint="$1"

    if [ ! -d "$mountpoint" ]; then
        print_log "Creating mount point: $mountpoint"
        mkdir -p "$mountpoint" || error "Failed to create mount point: $mountpoint"
        success "Created mount point: $mountpoint"
    else
        log "Mount point already exists: $mountpoint"
    fi
}

add_to_fstab() {
    local source="$1"
    local mountpoint="$2"
    local fstype="$3"
    local options="$4"
    local dump="$5"
    local pass="$6"

    local fstab_entry="$source $mountpoint $fstype $options $dump $pass"

    print_log "Adding to fstab: $fstab_entry"
    echo "$fstab_entry" >> "$FSTAB_FILE"
    success "Added to fstab"
}

mount_share() {
    local mountpoint="$1"

    print_log "Mounting: $mountpoint"

    if mountpoint -q "$mountpoint" 2>/dev/null; then
        info "Already mounted: $mountpoint"
        log "Already mounted: $mountpoint"
        return 0
    fi

    if mount "$mountpoint" 2>/dev/null; then
        success "Mounted successfully: $mountpoint"
        return 0
    else
        warn "Failed to mount: $mountpoint (will retry on next boot)"
        return 1
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [ "$default" = "y" ]; then
        read -p "$(echo -e ${CYAN}${prompt}${NC} [Y/n]: )" response
        response=${response,,} # to lowercase
        [[ -z "$response" || "$response" =~ ^y ]] && echo "yes" || echo "no"
    else
        read -p "$(echo -e ${CYAN}${prompt}${NC} [y/N]: )" response
        response=${response,,} # to lowercase
        [[ "$response" =~ ^y ]] && echo "yes" || echo "no"
    fi
}

print_banner() {
    echo ""
    echo -e "${BOLD}${BLUE}================================================================================${NC}"
    echo -e "${BOLD}${BLUE}                    NFS Mount Setup Script${NC}"
    echo -e "${BOLD}${BLUE}================================================================================${NC}"
    echo ""
}

################################################################################
# Main Functions
################################################################################

process_nfs_mount() {
    local mount_info="$1"

    # Parse mount info (source:mountpoint:fstype:options:dump:pass)
    IFS=':' read -r source mountpoint fstype options dump pass <<< "$mount_info"

    echo ""
    info "NFS Share: $source → $mountpoint"

    # Check if already in fstab
    if is_mount_in_fstab "$source" "$mountpoint"; then
        warn "This mount already exists in /etc/fstab"
        log "Skipped (already exists): $source → $mountpoint"

        # Ask if they want to try mounting it anyway
        local do_mount=$(prompt_yes_no "Do you want to mount it anyway?" "y")
        if [ "$do_mount" = "yes" ]; then
            create_mount_point "$mountpoint"
            mount_share "$mountpoint"
        fi
        return 0
    fi

    # Ask if user wants to add this mount
    local add_mount=$(prompt_yes_no "Add this NFS mount to /etc/fstab?" "y")

    if [ "$add_mount" = "yes" ]; then
        # Create mount point
        create_mount_point "$mountpoint"

        # Add to fstab
        add_to_fstab "$source" "$mountpoint" "$fstype" "$options" "$dump" "$pass"

        # Try to mount
        mount_share "$mountpoint"
    else
        log "Skipped by user: $source → $mountpoint"
        info "Skipped"
    fi
}

mount_all_fstab() {
    echo ""
    print_log "Mounting all filesystems from /etc/fstab"

    if mount -a 2>/dev/null; then
        success "All filesystems mounted successfully"
    else
        warn "Some filesystems failed to mount (check logs)"
    fi
}

print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo -e "${BOLD}${GREEN}                    Setup Summary${NC}"
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo ""

    info "Current NFS mounts:"
    mount | grep nfs || echo "  (none)"

    echo ""
    info "Relevant /etc/fstab entries:"
    grep "$NFS_SERVER" "$FSTAB_FILE" 2>/dev/null | while read -r line; do
        echo "  $line"
    done

    echo ""
    info "Backup saved to: $FSTAB_BACKUP"
    info "Log file: $LOG_FILE"
    echo ""
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo -e "${BOLD}${GREEN}                    Setup Complete!${NC}"
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo ""
}

################################################################################
# Main Script Execution
################################################################################

main() {
    # Start logging
    log "===== NFS Mount Setup Script Started ====="
    log "Running as: $(whoami)"
    log "Hostname: $(hostname)"
    log "Date: $(date)"

    # Print banner
    print_banner

    # Check root privileges
    check_root

    # Check NFS client installed
    check_nfs_client

    # Check if NFS server is reachable
    check_nfs_server_reachable "$NFS_SERVER"

    # Backup fstab
    backup_fstab

    # Process each NFS mount
    for mount_info in "${NFS_MOUNTS[@]}"; do
        process_nfs_mount "$mount_info"
    done

    # Ask if user wants to mount all from fstab
    echo ""
    local mount_all=$(prompt_yes_no "Run 'mount -a' to mount all filesystems from fstab?" "y")
    if [ "$mount_all" = "yes" ]; then
        mount_all_fstab
    fi

    # Print summary
    print_summary

    log "===== Script Completed Successfully ====="

    exit 0
}

# Run main function
main "$@"