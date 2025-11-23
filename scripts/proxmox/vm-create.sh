#!/bin/bash

################################################################################
# Proxmox VM Creation Script
#
# Creates a new VM by cloning an existing template with interactive prompts
# for configuration values.
#
# Usage: ./create-vm.sh
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

################################################################################
# Input Functions
################################################################################

get_template_id() {
    echo ""
    echo -e "${BLUE}Available Templates:${NC}"

    # List all VMs and identify templates
    qm list | head -1
    TEMPLATES_FOUND=0
    qm list | grep -v VMID | while read line; do
        vmid=$(echo "$line" | awk '{print $1}')
        if qm config "$vmid" 2>/dev/null | grep -q "template: 1"; then
            echo "$line [TEMPLATE]"
            TEMPLATES_FOUND=1
        fi
    done

    # Check if any templates were found
    if ! qm list | grep -v VMID | while read line; do
        vmid=$(echo "$line" | awk '{print $1}')
        qm config "$vmid" 2>/dev/null | grep -q "template: 1" && exit 0
    done; then
        warn "No templates found"
    fi

    echo ""

    while true; do
        read -p "Enter Template ID: " TEMPLATE_ID

        # Validate template exists
        if qm status "$TEMPLATE_ID" &>/dev/null; then
            # Check if it's actually a template
            if qm config "$TEMPLATE_ID" | grep -q "template: 1"; then
                log "Template $TEMPLATE_ID found"
                break
            else
                error "VM $TEMPLATE_ID exists but is not a template"
            fi
        else
            warn "Template ID $TEMPLATE_ID not found. Please try again."
        fi
    done
}

get_new_vm_id() {
    echo ""
    read -p "Enter new VM ID (or press Enter for next available): " NEW_VM_ID

    if [ -z "$NEW_VM_ID" ]; then
        # Get next available VM ID
        NEW_VM_ID=$(pvesh get /cluster/nextid)
        log "Using next available VM ID: $NEW_VM_ID"
    else
        # Validate VM ID doesn't already exist
        if qm status "$NEW_VM_ID" &>/dev/null; then
            error "VM ID $NEW_VM_ID already exists"
        fi
    fi
}

get_vm_name() {
    echo ""
    while true; do
        read -p "Enter VM Name: " VM_NAME

        if [ -z "$VM_NAME" ]; then
            warn "VM name cannot be empty. Please try again."
        else
            log "VM will be named: $VM_NAME"
            break
        fi
    done
}

get_clone_mode() {
    echo ""
    while true; do
        read -p "Clone Mode - (F)ull Clone or (L)inked Clone [F/L]: " -n 1 CLONE_MODE
        echo ""

        case ${CLONE_MODE^^} in
            F)
                CLONE_MODE="full"
                CLONE_PARAM=""
                log "Using Full Clone mode"
                break
                ;;
            L)
                CLONE_MODE="linked"
                CLONE_PARAM="--full 0"
                log "Using Linked Clone mode"
                break
                ;;
            *)
                warn "Invalid option. Please enter F for Full or L for Linked."
                ;;
        esac
    done
}

################################################################################
# VM Creation
################################################################################

create_vm() {
    log "Creating VM $NEW_VM_ID from template $TEMPLATE_ID..."

    # Build the clone command
    CMD="qm clone $TEMPLATE_ID $NEW_VM_ID --name $VM_NAME $CLONE_PARAM"

    info "Executing: $CMD"
    echo ""

    # Execute the clone command
    if eval "$CMD"; then
        log "VM created successfully!"
        return 0
    else
        error "Failed to create VM"
        return 1
    fi
}

start_vm() {
    echo ""
    read -p "Start the VM now? [Y/n]: " -n 1 START_VM
    echo ""

    if [[ ! $START_VM =~ ^[Nn]$ ]]; then
        log "Starting VM $NEW_VM_ID..."
        if qm start "$NEW_VM_ID"; then
            log "VM started successfully!"
            VM_STARTED=true

            # Wait for VM to boot and get IP address
            wait_for_ip
        else
            error "Failed to start VM"
        fi
    else
        log "VM start skipped"
        VM_STARTED=false
    fi
}

wait_for_ip() {
    info "Waiting for VM to boot and acquire IP address..."

    local max_attempts=60  # Wait up to 60 seconds
    local attempt=0
    VM_IP=""

    while [ $attempt -lt $max_attempts ]; do
        # Try to get IP from QEMU agent
        VM_IP=$(qm guest cmd "$NEW_VM_ID" network-get-interfaces 2>/dev/null | \
                grep -oP '"ip-address":\s*"\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=")' | \
                grep -v "127.0.0.1" | head -1)

        if [ -n "$VM_IP" ]; then
            log "VM IP address acquired: $VM_IP"
            return 0
        fi

        # Show progress
        echo -n "."
        sleep 1
        ((attempt++))
    done

    echo ""
    warn "Timeout waiting for IP address. The VM may still be booting."
    warn "Note: QEMU Guest Agent must be installed and running in the VM to retrieve IP address."
    return 1
}

show_vm_info() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}VM Created Successfully!${NC}"
    echo "================================================================================"
    echo ""
    echo "VM Details:"
    echo "  VM ID:        $NEW_VM_ID"
    echo "  Name:         $VM_NAME"
    echo "  Clone Type:   $CLONE_MODE"
    echo "  Storage:      local-lvm"
    echo "  Template:     $TEMPLATE_ID"
    if [ "$VM_STARTED" = true ]; then
        echo "  Status:       Running"
        if [ -n "$VM_IP" ]; then
            echo "  IP Address:   $VM_IP"
        fi
    else
        echo "  Status:       Stopped"
    fi
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Configure Cloud-Init (if template supports it):"
    echo -e "   ${YELLOW}Navigate to VM $NEW_VM_ID -> Cloud-Init tab in Proxmox GUI${NC}"
    echo ""
    echo "2. Adjust VM resources if needed:"
    echo -e "   ${YELLOW}qm set $NEW_VM_ID --memory <MB> --cores <NUM>${NC}"
    echo ""
    if [ "$VM_STARTED" = true ]; then
        echo "3. Open console:"
        echo -e "   ${YELLOW}Access via Proxmox GUI -> VM $NEW_VM_ID -> Console${NC}"
        if [ -n "$VM_IP" ]; then
            echo ""
            echo "4. Connect via SSH (if configured):"
            echo -e "   ${YELLOW}ssh user@$VM_IP${NC}"
        fi
    else
        echo "3. Start the VM:"
        echo -e "   ${YELLOW}qm start $NEW_VM_ID${NC}"
        echo ""
        echo "4. Open console:"
        echo -e "   ${YELLOW}Access via Proxmox GUI -> VM $NEW_VM_ID -> Console${NC}"
    fi
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
    echo "                    Proxmox VM Creation Script"
    echo "================================================================================"
    echo ""
    echo "This script will create a new VM by cloning an existing template."
    echo ""
    echo "Target Storage: local-lvm"
    echo ""
    echo "================================================================================"

    # Gather input
    get_template_id
    get_new_vm_id
    get_vm_name
    get_clone_mode

    # Confirmation
    echo ""
    echo "================================================================================"
    echo "                    Confirm VM Creation"
    echo "================================================================================"
    echo ""
    echo "  Template ID:      $TEMPLATE_ID"
    echo "  New VM ID:        $NEW_VM_ID"
    echo "  VM Name:          $VM_NAME"
    echo "  Clone Mode:       $CLONE_MODE"
    echo "  Storage:          local-lvm"
    echo ""
    echo "================================================================================"
    echo ""

    read -p "Proceed with VM creation? [Y/n]: " -n 1 CONFIRM
    echo ""

    if [[ ! $CONFIRM =~ ^[Yy]$ ]] && [[ -n $CONFIRM ]]; then
        warn "VM creation cancelled by user"
        exit 0
    fi

    # Create the VM
    create_vm

    # Start the VM (optional)
    start_vm

    # Show results
    show_vm_info
}

main "$@"
