#!/bin/bash

################################################################################
# Proxmox Batch VM Deletion Script
#
# Allows selection of multiple VMs for deletion with confirmation.
#
# Usage: ./batch-delete-vms.sh
################################################################################

# Note: set -e is NOT used here to allow the script to continue
# deleting VMs even if one deletion fails

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Array to store selected VM IDs
SELECTED_VMS=()

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
# VM Selection Functions
################################################################################

list_vms() {
    echo ""
    echo -e "${BLUE}Available VMs:${NC}"
    echo "================================================================================"

    # List all VMs (excluding templates)
    qm list | head -1  # Header
    qm list | grep -v template | tail -n +2 || warn "No VMs found (excluding templates)"

    echo "================================================================================"
    echo ""
}

get_vm_ids() {
    echo ""
    echo -e "${CYAN}Enter VM IDs to delete (space-separated), or type 'done' when finished:${NC}"
    echo -e "${YELLOW}Example: 301 302 303${NC}"
    echo ""

    while true; do
        read -p "VM IDs (or 'done'/'q' to finish): " INPUT

        # Check for done/quit
        if [[ "$INPUT" == "done" ]] || [[ "$INPUT" == "q" ]] || [[ "$INPUT" == "Q" ]]; then
            if [ ${#SELECTED_VMS[@]} -eq 0 ]; then
                warn "No VMs selected. Exiting."
                exit 0
            fi
            break
        fi

        # Split input by spaces and process each ID
        for VM_ID in $INPUT; do
            # Validate VM ID is a number
            if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
                warn "Invalid VM ID: $VM_ID (must be numeric)"
                continue
            fi

            # Validate VM exists
            if ! qm status "$VM_ID" &>/dev/null; then
                warn "VM ID $VM_ID not found"
                continue
            fi

            # Check if it's a template
            if qm config "$VM_ID" | grep -q "template: 1"; then
                warn "VM $VM_ID is a template. Use template-delete.sh instead."
                continue
            fi

            # Check if already selected
            if [[ " ${SELECTED_VMS[@]} " =~ " ${VM_ID} " ]]; then
                warn "VM $VM_ID already selected"
                continue
            fi

            # Add to selection
            SELECTED_VMS+=("$VM_ID")
            log "Added VM $VM_ID to deletion list"
        done

        echo ""
        if [ ${#SELECTED_VMS[@]} -gt 0 ]; then
            echo -e "${GREEN}Currently selected: ${SELECTED_VMS[@]}${NC}"
            echo ""
        fi
    done
}

display_selected_vms() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${YELLOW}VMs Selected for Deletion${NC}"
    echo "================================================================================"
    echo ""

    for VM_ID in "${SELECTED_VMS[@]}"; do
        VM_NAME=$(qm config "$VM_ID" | grep "^name:" | cut -d' ' -f2)
        VM_STATUS=$(qm status "$VM_ID" | awk '{print $2}')
        VM_MEMORY=$(qm config "$VM_ID" | grep "^memory:" | cut -d' ' -f2)
        VM_CORES=$(qm config "$VM_ID" | grep "^cores:" | cut -d' ' -f2)
        VM_DISKS=$(qm config "$VM_ID" | grep -E "^(scsi|sata|virtio|ide)[0-9]:" | wc -l)

        echo "  VM ID:        $VM_ID"
        echo "  Name:         $VM_NAME"
        echo "  Status:       $VM_STATUS"
        echo "  Memory:       ${VM_MEMORY}MB"
        echo "  CPU Cores:    ${VM_CORES}"
        echo "  Disks:        ${VM_DISKS}"
        echo ""
    done

    echo "================================================================================"
    echo -e "${RED}Total VMs to delete: ${#SELECTED_VMS[@]}${NC}"
    echo "================================================================================"
    echo ""
}

################################################################################
# VM Operations
################################################################################

stop_vms() {
    echo ""
    log "Stopping VMs if running..."
    echo ""

    for VM_ID in "${SELECTED_VMS[@]}"; do
        VM_STATUS=$(qm status "$VM_ID" | awk '{print $2}')

        if [[ "$VM_STATUS" == "running" ]]; then
            info "Stopping VM $VM_ID..."

            # Try graceful shutdown first
            if qm shutdown "$VM_ID" >/dev/null 2>&1; then
                info "  Waiting for graceful shutdown (max 30 seconds)..."
                WAIT_COUNT=0
                while [ $WAIT_COUNT -lt 30 ]; do
                    sleep 2
                    CURRENT_STATUS=$(qm status "$VM_ID" | awk '{print $2}')
                    if [[ "$CURRENT_STATUS" == "stopped" ]]; then
                        log "  VM $VM_ID stopped successfully"
                        break
                    fi
                    WAIT_COUNT=$((WAIT_COUNT + 2))
                done

                # Force stop if still running
                CURRENT_STATUS=$(qm status "$VM_ID" | awk '{print $2}')
                if [[ "$CURRENT_STATUS" == "running" ]]; then
                    warn "  Graceful shutdown timed out. Force stopping..."
                    qm stop "$VM_ID" >/dev/null 2>&1
                    log "  VM $VM_ID force stopped"
                fi
            else
                warn "  Graceful shutdown failed. Force stopping..."
                qm stop "$VM_ID" >/dev/null 2>&1
                log "  VM $VM_ID force stopped"
            fi
        else
            info "VM $VM_ID is already stopped"
        fi
    done

    echo ""
}

delete_vms() {
    echo ""
    log "Deleting VMs..."
    echo ""

    local SUCCESSFUL=0
    local FAILED=0

    for VM_ID in "${SELECTED_VMS[@]}"; do
        info "Deleting VM $VM_ID..."

        if qm destroy "$VM_ID" --purge >/dev/null 2>&1; then
            log "  VM $VM_ID deleted successfully"
            ((SUCCESSFUL++))
        else
            warn "  Failed to delete VM $VM_ID"
            ((FAILED++))
        fi
    done

    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Deletion Complete${NC}"
    echo "================================================================================"
    echo ""
    echo -e "  ${GREEN}Successful: $SUCCESSFUL${NC}"
    if [ $FAILED -gt 0 ]; then
        echo -e "  ${RED}Failed: $FAILED${NC}"
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
    echo "                    Proxmox Batch VM Deletion Script"
    echo "================================================================================"
    echo ""
    echo "This script will help you safely delete multiple VMs from your Proxmox"
    echo "environment."
    echo ""
    echo -e "${RED}WARNING: This action is irreversible! All VM data will be permanently deleted.${NC}"
    echo ""
    echo "================================================================================"

    # List VMs and get selection
    list_vms
    get_vm_ids

    # Display selected VMs
    display_selected_vms

    # Confirmation prompt
    echo -e "${RED}WARNING: You are about to permanently delete ${#SELECTED_VMS[@]} VM(s)!${NC}"
    echo ""
    echo "Selected VMs:"
    for VM_ID in "${SELECTED_VMS[@]}"; do
        VM_NAME=$(qm config "$VM_ID" | grep "^name:" | cut -d' ' -f2)
        echo "  - $VM_ID ($VM_NAME)"
    done
    echo ""
    echo -e "${YELLOW}Type 'iconsent' to confirm deletion:${NC}"
    read -p "> " CONFIRM

    if [[ "$CONFIRM" != "iconsent" ]]; then
        warn "Confirmation failed. Deletion cancelled."
        exit 0
    fi

    # Stop all selected VMs
    stop_vms

    # Delete all selected VMs
    delete_vms
}

main "$@"
