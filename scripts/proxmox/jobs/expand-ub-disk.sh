#!/bin/bash

################################################################################
# Ubuntu Server Disk Expansion Script
#
# Detects unpartitioned space after expanding a disk in Proxmox and extends
# the volume to use all available free space. Supports both traditional
# partitions and LVM setups.
#
# Usage: sudo ./expand-disk.sh
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

highlight() {
    echo -e "${CYAN}$1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

################################################################################
# Disk Detection Functions
################################################################################

detect_disk_info() {
    log "Detecting disk configuration..."
    echo ""

    # Get all block devices
    highlight "Current Disk Layout:"
    echo "================================================================================"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
    echo "================================================================================"
    echo ""

    # Detect primary disk (usually /dev/sda or /dev/vda)
    PRIMARY_DISK=$(lsblk -ndo NAME,TYPE | grep disk | head -1 | awk '{print $1}')

    if [ -z "$PRIMARY_DISK" ]; then
        error "Could not detect primary disk"
    fi

    DISK_PATH="/dev/${PRIMARY_DISK}"
    log "Primary disk detected: $DISK_PATH"
}

check_unpartitioned_space() {
    log "Checking for unpartitioned space..."

    # Get disk size and partitioned size
    DISK_SIZE=$(blockdev --getsize64 "$DISK_PATH")
    DISK_SIZE_GB=$(echo "scale=2; $DISK_SIZE / 1024 / 1024 / 1024" | bc)

    # Get the end of the last partition
    LAST_PART_END=$(parted "$DISK_PATH" unit B print free | grep "Free Space" | tail -1 | awk '{print $3}' | sed 's/B//')

    if [ -z "$LAST_PART_END" ]; then
        # No free space found
        FREE_SPACE=0
    else
        FREE_SPACE=$LAST_PART_END
    fi

    FREE_SPACE_GB=$(echo "scale=2; $FREE_SPACE / 1024 / 1024 / 1024" | bc)

    echo ""
    highlight "Disk Space Summary:"
    echo "================================================================================"
    echo "  Total Disk Size:        ${DISK_SIZE_GB} GB"
    echo "  Unpartitioned Space:    ${FREE_SPACE_GB} GB"
    echo "================================================================================"
    echo ""

    # Check if there's significant free space (more than 1GB)
    if (( $(echo "$FREE_SPACE_GB < 1" | bc -l) )); then
        warn "No significant unpartitioned space found (less than 1GB)"
        echo ""
        info "Nothing to expand. Exiting."
        exit 0
    fi

    HAS_FREE_SPACE=true
}

detect_filesystem_type() {
    log "Detecting filesystem configuration..."

    # Check if system uses LVM
    if pvdisplay >/dev/null 2>&1 && vgdisplay >/dev/null 2>&1; then
        USES_LVM=true
        log "LVM detected"

        # Get LVM info
        VG_NAME=$(vgdisplay | grep "VG Name" | awk '{print $3}' | head -1)
        ROOT_LV=$(lvdisplay | grep "LV Path" | grep -E "(root|lv-root)" | awk '{print $3}' | head -1)

        if [ -z "$VG_NAME" ] || [ -z "$ROOT_LV" ]; then
            error "Could not detect LVM configuration"
        fi

        log "Volume Group: $VG_NAME"
        log "Root Logical Volume: $ROOT_LV"
    else
        USES_LVM=false
        log "Standard partition layout detected (no LVM)"

        # Find root partition
        ROOT_PART=$(mount | grep "on / " | awk '{print $1}')
        if [ -z "$ROOT_PART" ]; then
            error "Could not detect root partition"
        fi

        log "Root partition: $ROOT_PART"
    fi

    # Get current filesystem info
    echo ""
    highlight "Current Filesystem Usage:"
    echo "================================================================================"
    df -h /
    echo "================================================================================"
    echo ""
}

################################################################################
# Partition Expansion Functions
################################################################################

expand_partition() {
    # Get the partition number of the last partition
    LAST_PART_NUM=$(parted "$DISK_PATH" print | grep "^ " | tail -1 | awk '{print $1}')

    if [ -z "$LAST_PART_NUM" ]; then
        error "Could not determine last partition number"
    fi

    log "Expanding partition $LAST_PART_NUM on $DISK_PATH..."

    # For LVM, we need to expand the physical volume partition
    if [ "$USES_LVM" = true ]; then
        # Find the PV partition
        PV_PART=$(pvdisplay | grep "PV Name" | awk '{print $3}' | head -1)
        PART_NUM=$(echo "$PV_PART" | grep -oP '\d+$')

        log "Expanding LVM physical volume partition: ${DISK_PATH}${PART_NUM}"

        # Use growpart to extend the partition
        if command -v growpart >/dev/null 2>&1; then
            log "Using growpart to expand partition..."
            growpart "$DISK_PATH" "$PART_NUM" || warn "growpart returned an error, but continuing..."
        else
            log "Installing cloud-guest-utils for growpart..."
            apt-get update -qq
            apt-get install -y cloud-guest-utils
            growpart "$DISK_PATH" "$PART_NUM" || warn "growpart returned an error, but continuing..."
        fi

        # Inform kernel of partition changes
        partprobe "$DISK_PATH" || true
        sleep 2

    else
        # Standard partition expansion
        log "Expanding partition ${DISK_PATH}${LAST_PART_NUM}..."

        if command -v growpart >/dev/null 2>&1; then
            growpart "$DISK_PATH" "$LAST_PART_NUM" || warn "growpart returned an error, but continuing..."
        else
            log "Installing cloud-guest-utils for growpart..."
            apt-get update -qq
            apt-get install -y cloud-guest-utils
            growpart "$DISK_PATH" "$LAST_PART_NUM" || warn "growpart returned an error, but continuing..."
        fi

        # Inform kernel of partition changes
        partprobe "$DISK_PATH" || true
        sleep 2
    fi

    log "Partition expanded successfully"
}

################################################################################
# LVM Expansion Functions
################################################################################

expand_lvm() {
    log "Expanding LVM configuration..."

    # Get the physical volume
    PV_PATH=$(pvdisplay | grep "PV Name" | awk '{print $3}' | head -1)

    log "Resizing physical volume: $PV_PATH"
    pvresize "$PV_PATH"

    log "Physical volume resized"

    # Show PV info
    echo ""
    highlight "Physical Volume Info:"
    pvdisplay "$PV_PATH"
    echo ""

    # Extend logical volume
    log "Extending logical volume: $ROOT_LV"

    # Get free space in VG
    VG_FREE=$(vgdisplay "$VG_NAME" | grep "Free" | awk '{print $7}')

    if [ -z "$VG_FREE" ] || [ "$VG_FREE" = "0" ]; then
        warn "No free space in volume group"
        return 1
    fi

    # Extend LV to use all free space
    log "Extending $ROOT_LV to use all free space in $VG_NAME..."
    lvextend -l +100%FREE "$ROOT_LV"

    log "Logical volume extended"

    # Show LV info
    echo ""
    highlight "Logical Volume Info:"
    lvdisplay "$ROOT_LV"
    echo ""
}

################################################################################
# Filesystem Resize Functions
################################################################################

resize_filesystem() {
    log "Resizing filesystem..."

    if [ "$USES_LVM" = true ]; then
        # For LVM, resize the filesystem on the logical volume
        FS_TYPE=$(lsblk -no FSTYPE "$ROOT_LV")

        case "$FS_TYPE" in
            ext4|ext3|ext2)
                log "Resizing ext filesystem on $ROOT_LV..."
                resize2fs "$ROOT_LV"
                ;;
            xfs)
                log "Resizing XFS filesystem on $ROOT_LV..."
                xfs_growfs /
                ;;
            *)
                error "Unsupported filesystem type: $FS_TYPE"
                ;;
        esac
    else
        # For standard partitions
        FS_TYPE=$(lsblk -no FSTYPE "$ROOT_PART")

        case "$FS_TYPE" in
            ext4|ext3|ext2)
                log "Resizing ext filesystem on $ROOT_PART..."
                resize2fs "$ROOT_PART"
                ;;
            xfs)
                log "Resizing XFS filesystem..."
                xfs_growfs /
                ;;
            *)
                error "Unsupported filesystem type: $FS_TYPE"
                ;;
        esac
    fi

    log "Filesystem resized successfully"
}

################################################################################
# Verification Functions
################################################################################

show_results() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Disk Expansion Complete!${NC}"
    echo "================================================================================"
    echo ""

    highlight "Updated Disk Layout:"
    echo "--------------------------------------------------------------------------------"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
    echo "--------------------------------------------------------------------------------"
    echo ""

    highlight "Updated Filesystem Usage:"
    echo "--------------------------------------------------------------------------------"
    df -h /
    echo "--------------------------------------------------------------------------------"
    echo ""

    if [ "$USES_LVM" = true ]; then
        highlight "LVM Status:"
        echo "--------------------------------------------------------------------------------"
        echo "Volume Group: $VG_NAME"
        vgdisplay "$VG_NAME" | grep -E "(VG Size|Free)"
        echo ""
        echo "Logical Volume: $ROOT_LV"
        lvdisplay "$ROOT_LV" | grep -E "(LV Size)"
        echo "--------------------------------------------------------------------------------"
        echo ""
    fi

    echo "================================================================================"
    echo ""
    log "Disk expansion completed successfully!"
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Ubuntu Server Disk Expansion Script"
    echo "================================================================================"
    echo ""
    echo "This script will detect unpartitioned space and expand your filesystem"
    echo "to use all available disk space."
    echo ""
    echo "================================================================================"
    echo ""

    # Check prerequisites
    check_root

    # Detect disk configuration
    detect_disk_info
    check_unpartitioned_space

    # Exit if no free space
    if [ "$HAS_FREE_SPACE" != true ]; then
        exit 0
    fi

    # Detect filesystem type
    detect_filesystem_type

    # Confirm expansion
    echo ""
    echo -e "${YELLOW}Ready to expand disk and filesystem${NC}"
    echo ""
    read -p "Do you want to proceed with disk expansion? [Y/n]: " CONFIRM
    echo ""

    if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
        warn "Operation cancelled by user"
        exit 0
    fi

    # Expand partition
    expand_partition

    # If LVM, expand PV and LV
    if [ "$USES_LVM" = true ]; then
        expand_lvm
    fi

    # Resize filesystem
    resize_filesystem

    # Show results
    show_results
}

main "$@"