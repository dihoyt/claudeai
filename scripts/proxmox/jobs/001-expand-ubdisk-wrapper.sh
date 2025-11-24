#!/bin/bash

################################################################################
# Proxmox VM Disk Expansion Wrapper Script
#
# Runs from Proxmox host to expand a VM's disk and filesystem.
# This script handles both the Proxmox disk resize and SSHing into the VM
# to run the filesystem expansion.
#
# Usage: ./expand-ubdisk-wrapper.sh <VMID> <DISK_SIZE>
# Example: ./expand-ubdisk-wrapper.sh 401 +20G
################################################################################

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

################################################################################
# Validation Functions
################################################################################

validate_args() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        error "Usage: $0 <VMID> <DISK_SIZE>\n  Example: $0 401 +20G"
    fi

    VMID="$1"
    DISK_SIZE="$2"

    # Validate VMID is a number
    if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
        error "VMID must be a number"
    fi

    # Validate VM exists
    if ! qm status "$VMID" &>/dev/null; then
        error "VM $VMID not found"
    fi

    # Validate disk size format
    if ! [[ "$DISK_SIZE" =~ ^\+?[0-9]+[KMGT]?$ ]]; then
        error "Invalid disk size format. Use +20G, 50G, etc."
    fi

    log "Target VM: $VMID"
    log "Disk size change: $DISK_SIZE"
}

get_vm_info() {
    VM_NAME=$(qm config "$VMID" | grep "^name:" | cut -d' ' -f2)
    VM_STATUS=$(qm status "$VMID" | awk '{print $2}')

    log "VM Name: $VM_NAME"
    log "VM Status: $VM_STATUS"
}

################################################################################
# Disk Operations (on Proxmox Host)
################################################################################

identify_disk() {
    log "Identifying VM disk configuration..."

    # Get disk configuration
    DISKS=$(qm config "$VMID" | grep -E "^(scsi|sata|virtio|ide)[0-9]:")

    if [ -z "$DISKS" ]; then
        error "No disks found for VM $VMID"
    fi

    # Try to identify the boot disk (usually scsi0 or virtio0)
    BOOT_DISK=""
    for disk_type in scsi0 virtio0 sata0 ide0; do
        if echo "$DISKS" | grep -q "^${disk_type}:"; then
            BOOT_DISK="$disk_type"
            break
        fi
    done

    if [ -z "$BOOT_DISK" ]; then
        # Fallback: use first disk found
        BOOT_DISK=$(echo "$DISKS" | head -1 | cut -d: -f1)
    fi

    log "Boot disk identified: $BOOT_DISK"

    # Show current disk info
    CURRENT_SIZE=$(qm config "$VMID" | grep "^${BOOT_DISK}:" | grep -oP 'size=[^,]+' | cut -d= -f2)
    log "Current size: $CURRENT_SIZE"
}

resize_disk() {
    echo ""
    highlight "Step 1: Resizing disk in Proxmox"
    echo "================================================================================"

    log "Resizing ${BOOT_DISK} to ${DISK_SIZE}..."

    if qm resize "$VMID" "$BOOT_DISK" "$DISK_SIZE"; then
        log "Disk resized successfully in Proxmox"

        # Show new size
        NEW_SIZE=$(qm config "$VMID" | grep "^${BOOT_DISK}:" | grep -oP 'size=[^,]+' | cut -d= -f2)
        log "New size: $NEW_SIZE"
    else
        error "Failed to resize disk in Proxmox"
    fi

    echo ""
}

################################################################################
# VM IP Detection
################################################################################

get_vm_ip() {
    log "Detecting VM IP address..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        # Try to get IP from QEMU agent
        VM_IP=$(qm guest cmd "$VMID" network-get-interfaces 2>/dev/null | \
                grep -oP '"ip-address":\s*"\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=")' | \
                grep -v "127.0.0.1" | head -1)

        if [ -n "$VM_IP" ]; then
            log "VM IP address: $VM_IP"
            return 0
        fi

        sleep 2
        ((attempt++))
    done

    error "Could not detect VM IP address. Ensure QEMU Guest Agent is installed and running."
}

################################################################################
# Filesystem Expansion (inside VM via SSH)
################################################################################

expand_filesystem() {
    echo ""
    highlight "Step 2: Expanding filesystem inside VM"
    echo "================================================================================"

    log "Connecting to VM via SSH..."

    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    EXPAND_SCRIPT="$SCRIPT_DIR/expand-ub-diskhost.sh"

    if [ ! -f "$EXPAND_SCRIPT" ]; then
        error "Expansion script not found at: $EXPAND_SCRIPT"
    fi

    # Copy expansion script to VM
    log "Copying expansion script to VM..."
    if ! scp -o StrictHostKeyChecking=no \
             -o UserKnownHostsFile=/dev/null \
             -o LogLevel=ERROR \
             "$EXPAND_SCRIPT" ubadmin@"$VM_IP":/tmp/expand-disk.sh; then
        error "Failed to copy script to VM"
    fi

    # Make script executable
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        ubadmin@"$VM_IP" "chmod +x /tmp/expand-disk.sh"

    echo ""
    log "Running filesystem expansion in VM..."
    echo ""

    # Run expansion script on VM (with auto-confirmation)
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        ubadmin@"$VM_IP" "echo 'Y' | sudo /tmp/expand-disk.sh"

    local exit_code=$?

    # Clean up
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        ubadmin@"$VM_IP" "rm -f /tmp/expand-disk.sh" 2>/dev/null || true

    if [ $exit_code -eq 0 ]; then
        echo ""
        log "Filesystem expansion completed successfully"
    else
        warn "Filesystem expansion may have encountered issues"
        return 1
    fi

    echo ""
}

################################################################################
# Results Display
################################################################################

show_results() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Disk Expansion Complete!${NC}"
    echo "================================================================================"
    echo ""
    echo "  VM ID:         $VMID"
    echo "  VM Name:       $VM_NAME"
    echo "  Disk:          $BOOT_DISK"
    echo "  New Size:      $NEW_SIZE"
    echo "  VM IP:         $VM_IP"
    echo ""
    echo "================================================================================"
    echo ""
    log "You can verify the expansion by SSHing into the VM:"
    echo -e "  ${YELLOW}ssh ubadmin@$VM_IP${NC}"
    echo -e "  ${YELLOW}df -h /${NC}"
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox VM Disk Expansion Wrapper"
    echo "================================================================================"
    echo ""
    echo "This script will:"
    echo "  1. Resize the VM disk in Proxmox"
    echo "  2. SSH into the VM and expand the filesystem"
    echo ""
    echo "================================================================================"
    echo ""

    # Validate arguments
    validate_args "$@"

    # Get VM info
    get_vm_info

    # Check if VM is running
    if [ "$VM_STATUS" != "running" ]; then
        error "VM must be running to expand filesystem. Current status: $VM_STATUS"
    fi

    # Identify the boot disk
    identify_disk

    # Confirm operation
    echo ""
    echo -e "${YELLOW}Ready to expand disk${NC}"
    echo ""
    read -p "Do you want to proceed? [Y/n]: " CONFIRM
    echo ""

    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        warn "Operation cancelled by user"
        exit 0
    fi

    # Step 1: Resize disk in Proxmox
    resize_disk

    # Step 2: Get VM IP address
    get_vm_ip

    # Step 3: Expand filesystem inside VM
    expand_filesystem

    # Show results
    show_results
}

main "$@"
