#!/bin/bash

################################################################################
# Proxmox VM Deletion Script
#
# Lists all VMs, allows selection, stops if running, and deletes the VM.
#
# Usage: ./delete-vm.sh
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

get_vm_id() {
    while true; do
        read -p "Enter VM ID to delete (or 'q' to quit): " VM_ID

        # Check for quit
        if [[ "$VM_ID" == "q" ]] || [[ "$VM_ID" == "Q" ]]; then
            log "Operation cancelled by user"
            exit 0
        fi

        # Validate VM ID is a number
        if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
            warn "Invalid VM ID. Please enter a numeric ID."
            continue
        fi

        # Validate VM exists
        if qm status "$VM_ID" &>/dev/null; then
            # Check if it's a template
            if qm config "$VM_ID" | grep -q "template: 1"; then
                warn "VM $VM_ID is a template. Use a different tool to delete templates."
                warn "To delete a template, use: qm destroy $VM_ID"
                continue
            else
                log "VM $VM_ID found"
                break
            fi
        else
            warn "VM ID $VM_ID not found. Please try again."
        fi
    done
}

get_vm_info() {
    VM_NAME=$(qm config "$VM_ID" | grep "^name:" | cut -d' ' -f2)
    VM_STATUS=$(qm status "$VM_ID" | awk '{print $2}')
    VM_MEMORY=$(qm config "$VM_ID" | grep "^memory:" | cut -d' ' -f2)
    VM_CORES=$(qm config "$VM_ID" | grep "^cores:" | cut -d' ' -f2)

    # Get disk info
    VM_DISKS=$(qm config "$VM_ID" | grep -E "^(scsi|sata|virtio|ide)[0-9]:" | wc -l)
}

display_vm_info() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${YELLOW}VM Information${NC}"
    echo "================================================================================"
    echo ""
    echo "  VM ID:        $VM_ID"
    echo "  Name:         $VM_NAME"
    echo "  Status:       $VM_STATUS"
    echo "  Memory:       ${VM_MEMORY}MB"
    echo "  CPU Cores:    ${VM_CORES}"
    echo "  Disks:        ${VM_DISKS}"
    echo ""
    echo "================================================================================"
    echo ""
}

################################################################################
# VM Operations
################################################################################

stop_vm_if_running() {
    if [[ "$VM_STATUS" == "running" ]]; then
        warn "VM $VM_ID is currently running"
        echo ""

        while true; do
            read -p "Stop the VM before deletion? (Y)es/(N)o/(F)orce stop: " -n 1 STOP_CHOICE
            echo ""
            echo ""

            case ${STOP_CHOICE^^} in
                Y)
                    log "Attempting graceful shutdown of VM $VM_ID..."
                    if qm shutdown "$VM_ID"; then
                        log "Shutdown command sent. Waiting for VM to stop..."

                        # Wait up to 60 seconds for graceful shutdown
                        WAIT_COUNT=0
                        while [ $WAIT_COUNT -lt 60 ]; do
                            sleep 2
                            CURRENT_STATUS=$(qm status "$VM_ID" | awk '{print $2}')
                            if [[ "$CURRENT_STATUS" == "stopped" ]]; then
                                log "VM stopped successfully"
                                VM_STATUS="stopped"
                                return 0
                            fi
                            WAIT_COUNT=$((WAIT_COUNT + 2))
                            echo -n "."
                        done

                        echo ""
                        warn "VM did not stop within 60 seconds"
                        read -p "Force stop the VM? [Y/n]: " -n 1 FORCE
                        echo ""
                        if [[ $FORCE =~ ^[Yy]$ ]] || [[ -z $FORCE ]]; then
                            log "Force stopping VM $VM_ID..."
                            qm stop "$VM_ID"
                            log "VM force stopped"
                            VM_STATUS="stopped"
                            return 0
                        else
                            error "Cannot delete a running VM. Operation cancelled."
                        fi
                    else
                        error "Failed to send shutdown command"
                    fi
                    break
                    ;;
                F)
                    log "Force stopping VM $VM_ID..."
                    if qm stop "$VM_ID"; then
                        log "VM force stopped"
                        VM_STATUS="stopped"
                        return 0
                    else
                        error "Failed to force stop VM"
                    fi
                    break
                    ;;
                N)
                    error "Cannot delete a running VM. Operation cancelled."
                    ;;
                *)
                    warn "Invalid option. Please enter Y, N, or F."
                    ;;
            esac
        done
    else
        info "VM is already stopped"
    fi
}

delete_vm() {
    log "Deleting VM $VM_ID..."

    if qm destroy "$VM_ID" --purge; then
        log "VM $VM_ID deleted successfully!"
        return 0
    else
        error "Failed to delete VM $VM_ID"
        return 1
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox VM Deletion Script"
    echo "================================================================================"
    echo ""
    echo "This script will help you safely delete a VM from your Proxmox environment."
    echo ""
    echo "WARNING: This action is irreversible! All VM data will be permanently deleted."
    echo ""
    echo "================================================================================"

    # List VMs and get selection
    list_vms
    get_vm_id
    get_vm_info
    display_vm_info

    # Confirm deletion
    echo -e "${RED}WARNING: You are about to delete this VM permanently!${NC}"
    echo ""
    read -p "Type the VM name '$VM_NAME' to confirm deletion: " CONFIRM_NAME
    echo ""

    if [[ "$CONFIRM_NAME" != "$VM_NAME" ]]; then
        warn "VM name does not match. Deletion cancelled."
        exit 0
    fi

    read -p "Are you absolutely sure you want to delete VM $VM_ID? [yes/NO]: " CONFIRM
    echo ""

    if [[ "$CONFIRM" != "yes" ]]; then
        warn "Deletion cancelled by user"
        exit 0
    fi

    # Stop VM if running
    stop_vm_if_running

    # Final confirmation
    echo ""
    echo -e "${RED}FINAL WARNING: Last chance to cancel!${NC}"
    read -p "Proceed with deletion of VM $VM_ID ($VM_NAME)? [yes/NO]: " FINAL_CONFIRM
    echo ""

    if [[ "$FINAL_CONFIRM" != "yes" ]]; then
        warn "Deletion cancelled by user"
        exit 0
    fi

    # Delete the VM
    delete_vm

    # Show completion message
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}VM Deleted Successfully!${NC}"
    echo "================================================================================"
    echo ""
    echo "  VM ID:        $VM_ID"
    echo "  VM Name:      $VM_NAME"
    echo ""
    echo "  Status:       DELETED"
    echo "  Disks:        PURGED"
    echo ""
    echo "================================================================================"
    echo ""
}

main "$@"
