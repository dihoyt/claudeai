#!/bin/bash

################################################################################
# Proxmox Ubuntu Server Creation Script
#
# Unattended creation of Ubuntu Server VMs by cloning template 200 with
# automatic naming based on existing ubuntusrv-* VMs.
#
# Features:
#  - Fully automated (no prompts)
#  - Automatic VM naming (ubuntusrv-01, ubuntusrv-02, etc.)
#  - Auto-start VM
#  - Clean progress display
#
# Usage: ./ubuntusrv-addhost.sh
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
TEMPLATE_ID=200
VM_PREFIX="ubuntusrv"
VM_ID_START=400

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
# Input Functions
################################################################################

get_node() {
    # Use current node
    NODE_NAME=$(hostname)
    log "Using current node: $NODE_NAME"
}

get_next_ubuntusrv_number() {
    log "Scanning for existing ubuntusrv-* VMs..."

    # Get all VM names and find ubuntusrv-XX pattern
    HIGHEST_NUM=0

    while read -r line; do
        vmid=$(echo "$line" | awk '{print $1}')
        if [ -n "$vmid" ]; then
            vm_name=$(qm config "$vmid" 2>/dev/null | grep "^name:" | awk '{print $2}')

            # Check if name matches ubuntusrv-XX pattern
            if [[ "$vm_name" =~ ^ubuntusrv-([0-9]+)$ ]]; then
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

    # Format with leading zero if needed (ubuntusrv-01, ubuntusrv-02, etc.)
    if [ "$NEXT_NUM" -lt 10 ]; then
        VM_NAME="${VM_PREFIX}-0${NEXT_NUM}"
    else
        VM_NAME="${VM_PREFIX}-${NEXT_NUM}"
    fi

    log "Next available name: $VM_NAME"
}

get_new_vm_id() {
    log "Finding next available VM ID starting from $VM_ID_START..."

    # Start from VM_ID_START and find first available ID
    CANDIDATE_ID=$VM_ID_START

    while true; do
        if ! qm status "$CANDIDATE_ID" &>/dev/null; then
            # ID is available
            NEW_VM_ID=$CANDIDATE_ID
            log "Using VM ID: $NEW_VM_ID"
            return 0
        fi

        # ID is taken, try next one
        ((CANDIDATE_ID++))

        # Safety check - don't go past 999
        if [ "$CANDIDATE_ID" -gt 999 ]; then
            error "No available VM IDs found in range $VM_ID_START-999"
        fi
    done
}

################################################################################
# Progress Display
################################################################################

show_progress() {
    local step=$1
    local status=$2
    local message=$3

    case $status in
        "running")
            echo -ne "\r  [$step/5] $message..."
            ;;
        "done")
            echo -e "\r  [$step/5] ${GREEN}✓${NC} $message"
            ;;
        "error")
            echo -e "\r  [$step/5] ${RED}✗${NC} $message"
            ;;
    esac
}

################################################################################
# VM Creation
################################################################################

verify_template() {
    show_progress 1 "running" "Verifying template"

    if ! qm status "$TEMPLATE_ID" &>/dev/null; then
        show_progress 1 "error" "Template $TEMPLATE_ID not found"
        error "Template $TEMPLATE_ID not found"
    fi

    # Check if it's actually a template
    if ! qm config "$TEMPLATE_ID" | grep -q "template: 1"; then
        show_progress 1 "error" "VM $TEMPLATE_ID is not a template"
        error "VM $TEMPLATE_ID exists but is not a template"
    fi

    show_progress 1 "done" "Template verified"
}

create_vm() {
    show_progress 2 "running" "Cloning VM $NEW_VM_ID ($VM_NAME)"
    echo ""

    # Build the clone command (full clone)
    CMD="qm clone $TEMPLATE_ID $NEW_VM_ID --name $VM_NAME --full 1"

    # Start the clone in background and capture the task ID
    TASK_OUTPUT=$(eval "$CMD" 2>&1)

    if [ $? -ne 0 ]; then
        show_progress 2 "error" "Failed to start clone"
        error "Failed to create VM: $TASK_OUTPUT"
        return 1
    fi

    # Extract UPID from output (format: UPID:node:XXXXXXXX:...)
    UPID=$(echo "$TASK_OUTPUT" | grep -oP 'UPID:[^\s]+' | head -1)

    if [ -n "$UPID" ]; then
        # Monitor the task with progress bar
        echo -ne "  Cloning progress: "

        while true; do
            # Check task status
            TASK_STATUS=$(qm task status "$UPID" 2>/dev/null)

            # Check if task is complete
            if echo "$TASK_STATUS" | grep -q "exitstatus.*OK"; then
                echo -e " ${GREEN}[100%]${NC} Complete"
                break
            elif echo "$TASK_STATUS" | grep -q "exitstatus"; then
                # Task failed
                echo -e " ${RED}[FAILED]${NC}"
                show_progress 2 "error" "Clone task failed"
                error "Clone operation failed"
                return 1
            fi

            # Show a simple progress spinner
            for i in / - \\ \|; do
                echo -ne "\b$i"
                sleep 0.2
            done
        done
        echo ""
    else
        # Fallback: just wait for VM to exist
        local wait_count=0
        while [ $wait_count -lt 60 ]; do
            if qm status "$NEW_VM_ID" &>/dev/null; then
                break
            fi
            echo -ne "."
            sleep 1
            ((wait_count++))
        done
        echo ""
    fi

    show_progress 2 "done" "VM cloned successfully"

    # Give the system a moment to register the new VM
    sleep 5

    return 0
}

start_vm() {
    show_progress 3 "running" "Starting VM"

    if qm start "$NEW_VM_ID" >/dev/null 2>&1; then
        show_progress 3 "done" "VM started"
        VM_STARTED=true

        # Give the VM time to boot before checking for IP
        sleep 10
    else
        show_progress 3 "error" "Failed to start VM"
        error "Failed to start VM"
    fi
}

wait_for_ip() {
    show_progress 4 "running" "Waiting for IP address"

    local max_attempts=60  # Wait up to 60 seconds
    local attempt=0
    VM_IP=""

    while [ $attempt -lt $max_attempts ]; do
        # Try to get IP from QEMU agent
        VM_IP=$(qm guest cmd "$NEW_VM_ID" network-get-interfaces 2>/dev/null | \
                grep -oP '"ip-address":\s*"\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=")' | \
                grep -v "127.0.0.1" | head -1)

        if [ -n "$VM_IP" ]; then
            show_progress 4 "done" "IP address acquired: $VM_IP"
            return 0
        fi

        sleep 1
        ((attempt++))
    done

    show_progress 4 "error" "Timeout waiting for IP address"
    warn "Note: QEMU Guest Agent must be installed and running in the VM"
    return 1
}

finalize() {
    show_progress 5 "done" "Ubuntu Server ready"
}

show_vm_info() {
    echo ""
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Ubuntu Server Created${NC}"
    echo "================================================================================"
    echo ""
    echo "  VM ID:    $NEW_VM_ID"
    echo "  Name:     $VM_NAME"
    echo "  Status:   Running"
    echo ""
    if [ -n "$VM_IP" ]; then
        echo "================================================================================"
        highlight "                    IP Address: $VM_IP"
        echo "================================================================================"
        echo ""
    else
        echo "IP address not yet available. Check with:"
        echo -e "  ${YELLOW}qm guest cmd $NEW_VM_ID network-get-interfaces${NC}"
        echo ""
        echo "================================================================================"
        echo ""
    fi
}

run_vm_setup() {
    if [ -z "$VM_IP" ]; then
        warn "No IP address available, skipping ubuntu-vm-setup.sh"
        return 1
    fi

    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SETUP_SCRIPT="$SCRIPT_DIR/jobs/ubuntu-vm-setup.sh"

    if [ ! -f "$SETUP_SCRIPT" ]; then
        warn "ubuntu-vm-setup.sh not found at: $SETUP_SCRIPT"
        echo ""
        echo "Run manually with: ./jobs/ubuntu-vm-setup.sh $VM_IP"
        echo ""
        return 1
    fi

    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Complete VM setup (cloud-init, reboot, SSH):"
    echo -e "     ${YELLOW}./jobs/ubuntu-vm-setup.sh $VM_IP${NC}"
    echo ""
    echo "  2. SSH directly:"
    echo -e "     ${YELLOW}ssh ubadmin@$VM_IP${NC}"
    echo ""
    echo "================================================================================"
    echo ""

    read -p "Run ubuntu-vm-setup.sh now? [y/N]: " RUN_SETUP
    echo ""

    if [[ "$RUN_SETUP" =~ ^[Yy]$ ]]; then
        # Run the setup script
        "$SETUP_SCRIPT" "$VM_IP"
    else
        log "Skipping automated setup. Run manually when ready."
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    echo "================================================================================"
    echo "                    Creating Ubuntu Server"
    echo "================================================================================"
    echo ""

    # Gather info silently
    get_node >/dev/null 2>&1
    get_next_ubuntusrv_number >/dev/null 2>&1
    get_new_vm_id >/dev/null 2>&1

    # Show what we're creating
    echo "  Creating: $VM_NAME (VM ID: $NEW_VM_ID)"
    echo ""

    # Execute steps with progress
    verify_template
    create_vm
    start_vm
    wait_for_ip
    finalize

    # Show results
    show_vm_info

    # Automatically run ubuntu-vm-setup.sh
    run_vm_setup
}

main "$@"
