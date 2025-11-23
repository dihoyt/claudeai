#!/bin/bash

################################################################################
# Proxmox Docker Host Creation Script
#
# Creates a new Docker host VM by cloning template 104 with automatic naming
# based on existing docker-* VMs.
#
# Usage: ./new-docker-host.sh
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEMPLATE_ID=104
VM_PREFIX="docker"

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

get_node() {
    # Use current node
    NODE_NAME=$(hostname)
    log "Using current node: $NODE_NAME"
}

get_next_docker_number() {
    log "Scanning for existing docker-* VMs..."

    # Get all VM names and find docker-XX pattern
    HIGHEST_NUM=0

    while read -r line; do
        vmid=$(echo "$line" | awk '{print $1}')
        if [ -n "$vmid" ]; then
            vm_name=$(qm config "$vmid" 2>/dev/null | grep "^name:" | awk '{print $2}')

            # Check if name matches docker-XX pattern
            if [[ "$vm_name" =~ ^docker-([0-9]+)$ ]]; then
                num="${BASH_REMATCH[1]}"
                # Remove leading zeros for comparison
                num=$((10#$num))
                if [ "$num" -gt "$HIGHEST_NUM" ]; then
                    HIGHEST_NUM=$num
                fi
            fi
        fi
    done < <(qm list | grep -v VMID)

    # Next number is highest + 1
    NEXT_NUM=$((HIGHEST_NUM + 1))

    # Format with leading zero if needed (docker-01, docker-02, etc.)
    if [ "$NEXT_NUM" -lt 10 ]; then
        VM_NAME="${VM_PREFIX}-0${NEXT_NUM}"
    else
        VM_NAME="${VM_PREFIX}-${NEXT_NUM}"
    fi

    log "Next available name: $VM_NAME"
}

get_new_vm_id() {
    # Get next available VM ID
    NEW_VM_ID=$(pvesh get /cluster/nextid)
    log "Using next available VM ID: $NEW_VM_ID"
}

################################################################################
# VM Creation
################################################################################

verify_template() {
    log "Verifying template $TEMPLATE_ID exists..."

    if ! qm status "$TEMPLATE_ID" &>/dev/null; then
        error "Template $TEMPLATE_ID not found"
    fi

    # Check if it's actually a template
    if ! qm config "$TEMPLATE_ID" | grep -q "template: 1"; then
        error "VM $TEMPLATE_ID exists but is not a template"
    fi

    log "Template $TEMPLATE_ID verified"
}

create_vm() {
    log "Creating VM $NEW_VM_ID ($VM_NAME) from template $TEMPLATE_ID..."

    # Build the clone command (full clone)
    CMD="qm clone $TEMPLATE_ID $NEW_VM_ID --name $VM_NAME --full 1"

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
    log "Starting VM $NEW_VM_ID..."
    if qm start "$NEW_VM_ID"; then
        log "VM started successfully!"
        VM_STARTED=true

        # Wait for VM to boot and get IP address
        wait_for_ip
    else
        error "Failed to start VM"
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
    echo -e "                    ${GREEN}Docker Host VM Created Successfully!${NC}"
    echo "================================================================================"
    echo ""
    echo "VM Details:"
    echo "  VM ID:        $NEW_VM_ID"
    echo "  Name:         $VM_NAME"
    echo "  Node:         $NODE_NAME"
    echo "  Clone Type:   Full Clone"
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
    echo "1. Adjust VM resources if needed:"
    echo -e "   ${YELLOW}qm set $NEW_VM_ID --memory <MB> --cores <NUM>${NC}"
    echo ""
    if [ "$VM_STARTED" = true ]; then
        echo "2. Open console:"
        echo -e "   ${YELLOW}Access via Proxmox GUI -> VM $NEW_VM_ID -> Console${NC}"
        if [ -n "$VM_IP" ]; then
            echo ""
            echo "3. Connect via SSH (if configured):"
            echo -e "   ${YELLOW}ssh user@$VM_IP${NC}"
            echo ""
            echo "4. Verify Docker installation:"
            echo -e "   ${YELLOW}docker --version${NC}"
        fi
    else
        echo "2. Start the VM:"
        echo -e "   ${YELLOW}qm start $NEW_VM_ID${NC}"
        echo ""
        echo "3. Open console:"
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
    log "Creating new Docker host VM from template $TEMPLATE_ID..."

    # Verify template exists
    verify_template

    # Gather info
    get_node
    get_next_docker_number
    get_new_vm_id

    # Create the VM
    create_vm

    # Start the VM
    start_vm

    # Show results
    show_vm_info
}

main "$@"