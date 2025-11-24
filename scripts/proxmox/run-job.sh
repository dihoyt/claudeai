#!/bin/bash

################################################################################
# Proxmox Job Runner Script
#
# Interactive script to run jobs on Proxmox VMs.
# Displays running VMs, available jobs, and executes selected job on target VM.
#
# Usage: ./run-job.sh
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
JOBS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/jobs" && pwd)"
CREDENTIALS_FILE="/.sshcredentials"

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

display_running_vms() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${BLUE}Running VMs${NC}"
    echo "================================================================================"
    echo ""

    # Print table header
    printf "${MAGENTA}%-10s %-30s %-15s${NC}\n" "VM ID" "VM Name" "IP Address"
    echo "--------------------------------------------------------------------------------"

    # Get list of running VMs
    local vm_data=()

    while read -r vmid; do
        if [ -n "$vmid" ]; then
            local status=$(qm status "$vmid" 2>/dev/null | awk '{print $2}')

            # Only show running VMs
            if [ "$status" = "running" ]; then
                local config=$(qm config "$vmid" 2>/dev/null)
                local name=$(echo "$config" | grep "^name:" | cut -d' ' -f2)
                local is_template=$(echo "$config" | grep "^template:" | cut -d' ' -f2)

                # Skip templates
                if [ "$is_template" != "1" ]; then
                    # Get IP address
                    local ip_address=$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
                                     grep -oP '"ip-address":\s*"\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=")' | \
                                     grep -v "127.0.0.1" | head -1)

                    # Store VM data
                    vm_data+=("$vmid|$name|${ip_address:-N/A}")

                    # Display VM info
                    printf "%-10s %-30s %-15s\n" "$vmid" "$name" "${ip_address:-N/A}"
                fi
            fi
        fi
    done < <(qm list | tail -n +2 | awk '{print $1}')

    echo "--------------------------------------------------------------------------------"
    echo ""

    # Return VM count
    echo "${#vm_data[@]}"
}

get_vm_selection() {
    local vm_count=$(display_running_vms)

    if [ "$vm_count" -eq 0 ]; then
        error "No running VMs found"
    fi

    # Prompt for VM ID
    echo -e "${YELLOW}Which VM (ID)?${NC}"
    read -p "> " SELECTED_VMID

    # Validate VM ID
    if ! [[ "$SELECTED_VMID" =~ ^[0-9]+$ ]]; then
        error "Invalid VM ID"
    fi

    # Check if VM exists and is running
    local status=$(qm status "$SELECTED_VMID" 2>/dev/null | awk '{print $2}')
    if [ "$status" != "running" ]; then
        error "VM $SELECTED_VMID is not running or does not exist"
    fi

    # Get VM details
    VM_NAME=$(qm config "$SELECTED_VMID" | grep "^name:" | cut -d' ' -f2)
    VM_IP=$(qm guest cmd "$SELECTED_VMID" network-get-interfaces 2>/dev/null | \
            grep -oP '"ip-address":\s*"\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=")' | \
            grep -v "127.0.0.1" | head -1)

    if [ -z "$VM_IP" ]; then
        error "Could not determine IP address for VM $SELECTED_VMID"
    fi

    log "Selected VM: $VM_NAME (ID: $SELECTED_VMID, IP: $VM_IP)"
}

################################################################################
# Job Selection Functions
################################################################################

display_available_jobs() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${BLUE}Available Jobs${NC}"
    echo "================================================================================"
    echo ""

    # Print table header
    printf "${MAGENTA}%-10s %-50s${NC}\n" "Job ID" "Job Name"
    echo "--------------------------------------------------------------------------------"

    # List job files
    local job_files=()

    if [ -d "$JOBS_DIR" ]; then
        while IFS= read -r -d '' file; do
            local basename=$(basename "$file")

            # Extract job ID (first 3 digits)
            if [[ "$basename" =~ ^([0-9]{3})-(.+)\.sh$ ]]; then
                local job_id="${BASH_REMATCH[1]}"
                local job_name="${BASH_REMATCH[2]}"

                job_files+=("$job_id|$basename")

                # Display job info
                printf "%-10s %-50s\n" "$job_id" "$job_name"
            fi
        done < <(find "$JOBS_DIR" -maxdepth 1 -name "[0-9][0-9][0-9]-*.sh" -print0 | sort -z)
    fi

    echo "--------------------------------------------------------------------------------"
    echo ""

    # Return job count
    echo "${#job_files[@]}"
}

get_job_selection() {
    local job_count=$(display_available_jobs)

    if [ "$job_count" -eq 0 ]; then
        error "No jobs found in $JOBS_DIR"
    fi

    # Prompt for Job ID
    echo -e "${YELLOW}Which job (ID)?${NC}"
    read -p "> " SELECTED_JOB_ID

    # Validate Job ID format
    if ! [[ "$SELECTED_JOB_ID" =~ ^[0-9]{3}$ ]]; then
        error "Invalid job ID format. Must be 3 digits (e.g., 001)"
    fi

    # Find matching job file
    JOB_FILE=$(find "$JOBS_DIR" -maxdepth 1 -name "${SELECTED_JOB_ID}-*.sh" -print -quit)

    if [ -z "$JOB_FILE" ]; then
        error "Job $SELECTED_JOB_ID not found"
    fi

    JOB_NAME=$(basename "$JOB_FILE" .sh | sed "s/^${SELECTED_JOB_ID}-//")

    log "Selected job: $JOB_NAME (ID: $SELECTED_JOB_ID)"
}

################################################################################
# Credential Functions
################################################################################

load_credentials() {
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        error "Credentials file not found at $CREDENTIALS_FILE"
    fi

    # Source credentials file
    source "$CREDENTIALS_FILE"

    if [ -z "$username" ] || [ -z "$password" ]; then
        error "Credentials file must contain 'username=' and 'password=' variables"
    fi

    SSH_USER="$username"
    SSH_PASS="$password"
}

################################################################################
# Job Execution Functions
################################################################################

confirm_execution() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${YELLOW}Confirmation${NC}"
    echo "================================================================================"
    echo ""
    echo "  Job:      $JOB_NAME"
    echo "  VM:       $VM_NAME (ID: $SELECTED_VMID)"
    echo "  IP:       $VM_IP"
    echo ""
    echo -e "${YELLOW}Run $JOB_NAME on $VM_NAME?${NC}"
    read -p "[Y/n]: " CONFIRM
    echo ""

    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        warn "Execution cancelled by user"
        exit 0
    fi
}

execute_job() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Executing Job${NC}"
    echo "================================================================================"
    echo ""

    log "Copying job script to VM..."

    # Copy job to VM
    if ! scp -o StrictHostKeyChecking=no \
             -o UserKnownHostsFile=/dev/null \
             -o LogLevel=ERROR \
             "$JOB_FILE" "$SSH_USER@$VM_IP:/tmp/job.sh" 2>/dev/null; then
        error "Failed to copy job script to VM"
    fi

    log "Making script executable..."
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "$SSH_USER@$VM_IP" "chmod +x /tmp/job.sh" 2>/dev/null

    echo ""
    log "Running job on VM as sudo..."
    echo ""
    echo "--------------------------------------------------------------------------------"

    # Execute job on VM with sudo
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -t "$SSH_USER@$VM_IP" "echo '$SSH_PASS' | sudo -S /tmp/job.sh"

    local exit_code=$?

    echo "--------------------------------------------------------------------------------"
    echo ""

    # Clean up
    log "Cleaning up..."
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "$SSH_USER@$VM_IP" "rm -f /tmp/job.sh" 2>/dev/null || true

    if [ $exit_code -eq 0 ]; then
        echo ""
        echo "================================================================================"
        echo -e "                    ${GREEN}Job Completed Successfully!${NC}"
        echo "================================================================================"
        echo ""
    else
        echo ""
        echo "================================================================================"
        echo -e "                    ${RED}Job Failed (Exit Code: $exit_code)${NC}"
        echo "================================================================================"
        echo ""
        exit $exit_code
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox Job Runner"
    echo "================================================================================"
    echo ""
    echo "This script will:"
    echo "  1. Display running VMs and prompt for selection"
    echo "  2. Display available jobs and prompt for selection"
    echo "  3. Execute the selected job on the target VM as sudo"
    echo ""
    echo "================================================================================"

    # Load credentials
    load_credentials

    # Step 1: Select VM
    get_vm_selection

    # Step 2: Select Job
    get_job_selection

    # Step 3: Confirm execution
    confirm_execution

    # Step 4: Execute job
    execute_job

    log "Done!"
    echo ""
}

main "$@"