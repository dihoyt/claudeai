#!/bin/bash

################################################################################
# Proxmox Template Deletion Script
#
# Lists all templates, allows selection, and deletes the chosen template.
#
# Usage: ./template-delete.sh
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
# Template Selection Functions
################################################################################

list_templates() {
    echo ""
    echo -e "${BLUE}Available Templates:${NC}"
    echo "================================================================================"

    # List all templates
    qm list | head -1  # Header

    # Get templates (grep will filter lines containing 'template')
    TEMPLATE_LIST=$(qm list | grep template)

    if [ -n "$TEMPLATE_LIST" ]; then
        echo "$TEMPLATE_LIST"
    else
        warn "No templates found"
        echo "================================================================================"
        echo ""
        exit 0
    fi

    echo "================================================================================"
    echo ""
}

get_template_id() {
    while true; do
        read -p "Enter Template ID to delete (or 'q' to quit): " TEMPLATE_ID

        # Check for quit
        if [[ "$TEMPLATE_ID" == "q" ]] || [[ "$TEMPLATE_ID" == "Q" ]]; then
            log "Operation cancelled by user"
            exit 0
        fi

        # Validate Template ID is a number
        if ! [[ "$TEMPLATE_ID" =~ ^[0-9]+$ ]]; then
            warn "Invalid Template ID. Please enter a numeric ID."
            continue
        fi

        # Validate Template exists
        if qm status "$TEMPLATE_ID" &>/dev/null; then
            # Check if it's actually a template
            if qm config "$TEMPLATE_ID" | grep -q "template: 1"; then
                log "Template $TEMPLATE_ID found"
                break
            else
                warn "VM $TEMPLATE_ID is not a template. Use delete-vm.sh instead."
                continue
            fi
        else
            warn "Template ID $TEMPLATE_ID not found. Please try again."
        fi
    done
}

get_template_info() {
    TEMPLATE_NAME=$(qm config "$TEMPLATE_ID" | grep "^name:" | cut -d' ' -f2)
    TEMPLATE_MEMORY=$(qm config "$TEMPLATE_ID" | grep "^memory:" | cut -d' ' -f2)
    TEMPLATE_CORES=$(qm config "$TEMPLATE_ID" | grep "^cores:" | cut -d' ' -f2)

    # Get disk info
    TEMPLATE_DISKS=$(qm config "$TEMPLATE_ID" | grep -E "^(scsi|sata|virtio|ide)[0-9]:" | wc -l)

    # Get OS type if available
    TEMPLATE_OS=$(qm config "$TEMPLATE_ID" | grep "^ostype:" | cut -d' ' -f2 || echo "Unknown")
}

display_template_info() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${YELLOW}Template Information${NC}"
    echo "================================================================================"
    echo ""
    echo "  Template ID:  $TEMPLATE_ID"
    echo "  Name:         $TEMPLATE_NAME"
    echo "  OS Type:      $TEMPLATE_OS"
    echo "  Memory:       ${TEMPLATE_MEMORY}MB"
    echo "  CPU Cores:    ${TEMPLATE_CORES}"
    echo "  Disks:        ${TEMPLATE_DISKS}"
    echo ""
    echo "================================================================================"
    echo ""
}

################################################################################
# Template Operations
################################################################################

delete_template() {
    log "Deleting template $TEMPLATE_ID..."

    if qm destroy "$TEMPLATE_ID" --purge; then
        log "Template $TEMPLATE_ID deleted successfully!"
        return 0
    else
        error "Failed to delete template $TEMPLATE_ID"
        return 1
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox Template Deletion Script"
    echo "================================================================================"
    echo ""
    echo "This script will help you safely delete a template from your Proxmox environment."
    echo ""
    echo "WARNING: This action is irreversible! All template data will be permanently deleted."
    echo ""
    echo "================================================================================"

    # List templates and get selection
    list_templates
    get_template_id
    get_template_info
    display_template_info

    # Confirm deletion
    echo -e "${RED}WARNING: You are about to delete this template permanently!${NC}"
    echo ""
    read -p "Type the template name '$TEMPLATE_NAME' to confirm deletion: " CONFIRM_NAME
    echo ""

    if [[ "$CONFIRM_NAME" != "$TEMPLATE_NAME" ]]; then
        warn "Template name does not match. Deletion cancelled."
        exit 0
    fi

    read -p "Are you absolutely sure you want to delete template $TEMPLATE_ID? [yes/NO]: " CONFIRM
    echo ""

    if [[ "$CONFIRM" != "yes" ]]; then
        warn "Deletion cancelled by user"
        exit 0
    fi

    # Final confirmation
    echo ""
    echo -e "${RED}FINAL WARNING: Last chance to cancel!${NC}"
    read -p "Proceed with deletion of template $TEMPLATE_ID ($TEMPLATE_NAME)? [yes/NO]: " FINAL_CONFIRM
    echo ""

    if [[ "$FINAL_CONFIRM" != "yes" ]]; then
        warn "Deletion cancelled by user"
        exit 0
    fi

    # Delete the template
    delete_template

    # Show completion message
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Template Deleted Successfully!${NC}"
    echo "================================================================================"
    echo ""
    echo "  Template ID:  $TEMPLATE_ID"
    echo "  Name:         $TEMPLATE_NAME"
    echo ""
    echo "  Status:       DELETED"
    echo "  Disks:        PURGED"
    echo ""
    echo "================================================================================"
    echo ""
}

main "$@"