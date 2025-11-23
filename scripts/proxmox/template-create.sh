#!/bin/bash

################################################################################
# Proxmox Template Creation Script
#
# Lists all VMs, allows selection, and converts the chosen VM to a template.
#
# Usage: ./template-create.sh
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
# VM Selection Functions
################################################################################

list_vms() {
    echo ""
    highlight "Available VMs (non-templates):"
    echo "================================================================================"

    # List all VMs with header
    qm list | head -1

    # Get non-template VMs
    VM_LIST=""
    while IFS= read -r line; do
        vmid=$(echo "$line" | awk '{print $1}')

        # Skip if it's a template
        if qm config "$vmid" 2>/dev/null | grep -q "template: 1"; then
            continue
        fi

        # Get VM status
        status=$(qm status "$vmid" 2>/dev/null | awk '{print $2}')

        # Display VM with status
        echo "$line [$status]"
        VM_LIST="$VM_LIST $vmid"
    done < <(qm list | grep -v VMID)

    if [ -z "$VM_LIST" ]; then
        warn "No non-template VMs found"
        echo "================================================================================"
        echo ""
        exit 0
    fi

    echo "================================================================================"
    echo ""
}

get_vm_id() {
    while true; do
        read -p "Enter VM ID to convert to template (or 'q' to quit): " VM_ID

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
            # Check if it's already a template
            if qm config "$VM_ID" | grep -q "template: 1"; then
                warn "VM $VM_ID is already a template."
                continue
            fi

            log "VM $VM_ID found"
            break
        else
            warn "VM ID $VM_ID not found. Please try again."
        fi
    done
}

get_vm_info() {
    VM_NAME=$(qm config "$VM_ID" | grep "^name:" | cut -d' ' -f2)
    VM_MEMORY=$(qm config "$VM_ID" | grep "^memory:" | cut -d' ' -f2)
    VM_CORES=$(qm config "$VM_ID" | grep "^cores:" | cut -d' ' -f2)
    VM_STATUS=$(qm status "$VM_ID" | awk '{print $2}')

    # Get disk info
    VM_DISKS=$(qm config "$VM_ID" | grep -E "^(scsi|sata|virtio|ide)[0-9]:" | wc -l)

    # Get OS type if available
    VM_OS=$(qm config "$VM_ID" | grep "^ostype:" | cut -d' ' -f2 || echo "Unknown")
}

display_vm_info() {
    echo ""
    echo "================================================================================"
    highlight "                    VM Information"
    echo "================================================================================"
    echo ""
    echo "  VM ID:        $VM_ID"
    echo "  Name:         $VM_NAME"
    echo "  Status:       $VM_STATUS"
    echo "  OS Type:      $VM_OS"
    echo "  Memory:       ${VM_MEMORY}MB"
    echo "  CPU Cores:    ${VM_CORES}"
    echo "  Disks:        ${VM_DISKS}"
    echo ""
    echo "================================================================================"
    echo ""
}

################################################################################
# VM Preparation Functions
################################################################################

check_vm_status() {
    if [[ "$VM_STATUS" == "running" ]]; then
        warn "VM $VM_ID is currently running!"
        echo ""
        echo "The VM must be stopped before converting to a template."
        echo ""
        read -p "Would you like to shut down the VM now? [y/N]: " SHUTDOWN_VM
        echo ""

        if [[ "$SHUTDOWN_VM" =~ ^[Yy]$ ]]; then
            log "Shutting down VM $VM_ID..."

            if qm shutdown "$VM_ID" --timeout 60; then
                log "VM $VM_ID shut down successfully"

                # Wait for VM to fully stop
                info "Waiting for VM to stop completely..."
                for i in {1..30}; do
                    sleep 2
                    if [[ $(qm status "$VM_ID" | awk '{print $2}') == "stopped" ]]; then
                        log "VM has stopped"
                        VM_STATUS="stopped"
                        return 0
                    fi
                done

                warn "VM did not stop gracefully. Forcing stop..."
                qm stop "$VM_ID"
                VM_STATUS="stopped"
            else
                error "Failed to shut down VM $VM_ID. Please shut down manually and try again."
            fi
        else
            warn "VM must be stopped before conversion. Please stop the VM and run this script again."
            exit 0
        fi
    fi
}

suggest_cleanup() {
    echo ""
    highlight "Template Preparation Recommendations:"
    echo "================================================================================"
    echo ""
    echo "Before converting to a template, consider the following cleanup tasks:"
    echo ""
    echo "  1. Remove SSH host keys (regenerated on first boot)"
    echo "  2. Remove machine-id (regenerated on first boot)"
    echo "  3. Clear shell history"
    echo "  4. Remove temporary files"
    echo "  5. Clear log files"
    echo "  6. Remove cloud-init data (if applicable)"
    echo ""
    echo "These tasks should typically be done BEFORE shutting down the VM."
    echo ""
    echo "================================================================================"
    echo ""

    read -p "Have you performed template preparation tasks? [y/N]: " PREP_DONE
    echo ""

    if [[ ! "$PREP_DONE" =~ ^[Yy]$ ]]; then
        warn "Consider preparing the VM before converting to a template."
        echo ""
        read -p "Do you want to continue anyway? [y/N]: " CONTINUE_ANYWAY
        echo ""

        if [[ ! "$CONTINUE_ANYWAY" =~ ^[Yy]$ ]]; then
            log "Template creation cancelled. Please prepare the VM and try again."
            exit 0
        fi
    fi
}

################################################################################
# Template Operations
################################################################################

convert_to_template() {
    log "Converting VM $VM_ID to template..."
    echo ""

    if qm template "$VM_ID"; then
        log "VM $VM_ID successfully converted to template!"
        return 0
    else
        error "Failed to convert VM $VM_ID to template"
        return 1
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox Template Creation Script"
    echo "================================================================================"
    echo ""
    echo "This script will help you convert a VM to a template."
    echo ""
    echo "IMPORTANT: Once converted to a template, the VM cannot be started directly."
    echo "You must clone the template to create new VMs."
    echo ""
    echo "================================================================================"

    # Check prerequisites
    check_root

    # List VMs and get selection
    list_vms
    get_vm_id
    get_vm_info
    display_vm_info

    # Check VM status and prepare
    check_vm_status
    suggest_cleanup

    # Confirm conversion
    echo -e "${YELLOW}WARNING: This will convert the VM to a template (irreversible)!${NC}"
    echo ""
    read -p "Type the VM name '$VM_NAME' to confirm conversion: " CONFIRM_NAME
    echo ""

    if [[ "$CONFIRM_NAME" != "$VM_NAME" ]]; then
        warn "VM name does not match. Conversion cancelled."
        exit 0
    fi

    read -p "Proceed with converting VM $VM_ID to a template? [yes/NO]: " CONFIRM
    echo ""

    if [[ "$CONFIRM" != "yes" ]]; then
        warn "Template creation cancelled by user"
        exit 0
    fi

    # Convert to template
    convert_to_template

    # Show completion message
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Template Created Successfully!${NC}"
    echo "================================================================================"
    echo ""
    echo "  Template ID:  $VM_ID"
    echo "  Name:         $VM_NAME"
    echo "  OS Type:      $VM_OS"
    echo "  Memory:       ${VM_MEMORY}MB"
    echo "  CPU Cores:    ${VM_CORES}"
    echo ""
    echo "================================================================================"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  • Clone this template to create new VMs"
    echo "  • View in Proxmox web UI (marked with template icon)"
    echo "  • Use vm-create.sh script to clone from this template"
    echo ""
    echo "  To clone manually:"
    echo "    qm clone $VM_ID <new-vm-id> --name <new-vm-name>"
    echo ""
    echo "================================================================================"
    echo ""
}

main "$@"
