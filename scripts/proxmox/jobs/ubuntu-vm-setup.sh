#!/bin/bash

################################################################################
# Ubuntu VM Setup Helper Script
#
# Final setup step for Ubuntu-based VMs. Waits for cloud-init to complete,
# reboots the VM, waits for it to come back online, and SSHs into it.
#
# This script is designed to be called after VM creation from:
#  - vm-create.sh
#  - docker-addhost.sh
#
# Usage: ./ubuntu-vm-setup.sh <VM_IP_ADDRESS>
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
SSH_USER="ubadmin"
MAX_CLOUDINIT_WAIT=300  # 5 minutes
MAX_BOOT_WAIT=120       # 2 minutes

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
# Validation
################################################################################

validate_args() {
    if [ -z "$1" ]; then
        error "Usage: $0 <VM_IP_ADDRESS>"
    fi

    VM_IP="$1"

    # Validate IP address format
    if ! [[ "$VM_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "Invalid IP address format: $VM_IP"
    fi

    log "Target VM IP: $VM_IP"
}

################################################################################
# Cloud-init Functions
################################################################################

wait_for_ssh_ready() {
    info "Waiting for SSH to be available on $VM_IP..."

    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if nc -z -w 2 "$VM_IP" 22 &>/dev/null; then
            echo ""
            log "SSH port is open"
            return 0
        fi

        echo -n "."
        sleep 2
        ((attempt++))
    done

    echo ""
    warn "SSH port did not become available"
    return 1
}

wait_for_cloudinit() {
    info "Waiting for cloud-init to complete on $VM_IP..."
    echo ""

    local attempt=0
    local cloudinit_done=false

    while [ $attempt -lt $MAX_CLOUDINIT_WAIT ]; do
        # Try to check cloud-init status via SSH
        CLOUDINIT_STATUS=$(ssh -o ConnectTimeout=5 \
                               -o StrictHostKeyChecking=no \
                               -o UserKnownHostsFile=/dev/null \
                               -o LogLevel=ERROR \
                               "$SSH_USER@$VM_IP" \
                               "cloud-init status --wait 2>/dev/null || echo 'unknown'" 2>/dev/null | tail -1)

        if echo "$CLOUDINIT_STATUS" | grep -q "done"; then
            echo ""
            log "Cloud-init has completed successfully!"
            cloudinit_done=true
            break
        elif echo "$CLOUDINIT_STATUS" | grep -q "error"; then
            echo ""
            warn "Cloud-init reported an error status"
            break
        fi

        # Show progress every 5 seconds
        if [ $((attempt % 5)) -eq 0 ]; then
            echo -n "."
        fi

        sleep 1
        ((attempt++))
    done

    if [ "$cloudinit_done" = false ]; then
        echo ""
        warn "Cloud-init did not complete within $MAX_CLOUDINIT_WAIT seconds"
        echo ""
        read -p "Continue anyway? [y/N]: " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            error "Setup cancelled by user"
        fi
    fi

    return 0
}

################################################################################
# VM Reboot Functions
################################################################################

reboot_vm() {
    echo ""
    log "Rebooting VM to finalize cloud-init configuration..."

    # Reboot via SSH
    if ssh -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR \
           "$SSH_USER@$VM_IP" \
           "sudo reboot" 2>/dev/null; then
        log "Reboot command sent successfully"
    else
        # SSH connection drops during reboot, this is expected
        log "Reboot initiated (connection dropped as expected)"
    fi

    # Wait for VM to shut down
    info "Waiting for VM to shut down..."
    sleep 10

    return 0
}

wait_for_vm_online() {
    info "Waiting for VM to come back online..."

    local max_attempts=$MAX_BOOT_WAIT
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        # Check if SSH is responding
        if nc -z -w 2 "$VM_IP" 22 &>/dev/null; then
            # Try a simple SSH command
            if ssh -o ConnectTimeout=5 \
                   -o StrictHostKeyChecking=no \
                   -o UserKnownHostsFile=/dev/null \
                   -o LogLevel=ERROR \
                   "$SSH_USER@$VM_IP" \
                   "echo 'online'" &>/dev/null; then
                echo ""
                log "VM is back online and SSH is responding"
                return 0
            fi
        fi

        echo -n "."
        sleep 2
        ((attempt++))
    done

    echo ""
    error "Timeout waiting for VM to come back online"
    return 1
}

################################################################################
# SSH Connection
################################################################################

ssh_into_vm() {
    echo ""
    echo "================================================================================"
    highlight "                    Connecting to VM via SSH"
    echo "================================================================================"
    echo ""
    log "Connecting to $SSH_USER@$VM_IP..."
    echo ""
    info "You are now connected to the VM. Type 'exit' to disconnect."
    echo ""
    sleep 2

    # SSH into the VM
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$SSH_USER@$VM_IP"
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Ubuntu VM Setup Helper"
    echo "================================================================================"
    echo ""
    echo "This script will complete the final setup steps for your Ubuntu VM:"
    echo ""
    echo "  1. Wait for cloud-init to complete"
    echo "  2. Reboot the VM"
    echo "  3. Wait for VM to come back online"
    echo "  4. SSH into the VM as $SSH_USER"
    echo ""
    echo "================================================================================"
    echo ""

    # Validate arguments
    validate_args "$@"

    # Wait for SSH to be ready
    wait_for_ssh_ready

    # Wait for cloud-init
    wait_for_cloudinit

    # Reboot the VM
    reboot_vm

    # Wait for VM to come back online
    wait_for_vm_online

    # SSH into the VM
    ssh_into_vm

    # Done
    echo ""
    echo "================================================================================"
    log "VM setup complete!"
    echo "================================================================================"
    echo ""
}

main "$@"