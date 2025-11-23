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
    # List all templates
    qm list | grep -i template || warn "No templates found"
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
    CMD="qm clone $TEMPLATE_ID $NEW_VM_ID --name $VM_NAME --storage local-lvm $CLONE_PARAM"

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
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Configure Cloud-Init (if template supports it):"
    echo -e "   ${YELLOW}Navigate to VM $NEW_VM_ID -> Cloud-Init tab in Proxmox GUI${NC}"
    echo ""
    echo "2. Adjust VM resources if needed:"
    echo -e "   ${YELLOW}qm set $NEW_VM_ID --memory <MB> --cores <NUM>${NC}"
    echo ""
    echo "3. Start the VM:"
    echo -e "   ${YELLOW}qm start $NEW_VM_ID${NC}"
    echo ""
    echo "4. Open console:"
    echo -e "   ${YELLOW}Access via Proxmox GUI -> VM $NEW_VM_ID -> Console${NC}"
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

    # Show results
    show_vm_info
}

main "$@"
