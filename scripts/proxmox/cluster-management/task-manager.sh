#!/bin/bash

################################################################################
# Proxmox Task Manager
#
# Displays host statistics and VM information in a formatted table.
# Provides real-time monitoring of Proxmox host and virtual machines.
#
# Usage: ./task-manager.sh [--watch]
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

get_host_stats() {
    # CPU Information
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    CPU_CORES=$(nproc)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

    # Load Average
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)

    # Memory Information
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
    MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100.0}')

    # Disk Information (root partition)
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

    # Storage pool information (local-lvm)
    if pvesm status | grep -q "local-lvm"; then
        STORAGE_TOTAL=$(pvesm status -storage local-lvm | awk 'NR==2 {printf "%.1fG", $4/1024/1024/1024}')
        STORAGE_USED=$(pvesm status -storage local-lvm | awk 'NR==2 {printf "%.1fG", $5/1024/1024/1024}')
        STORAGE_AVAIL=$(pvesm status -storage local-lvm | awk 'NR==2 {printf "%.1fG", $6/1024/1024/1024}')
        STORAGE_PERCENT=$(pvesm status -storage local-lvm | awk 'NR==2 {printf "%.1f", ($5/$4)*100}')
    else
        STORAGE_TOTAL="N/A"
        STORAGE_USED="N/A"
        STORAGE_AVAIL="N/A"
        STORAGE_PERCENT="0"
    fi

    # Uptime
    UPTIME=$(uptime -p | sed 's/up //')

    # Network interfaces and IPs
    PRIMARY_IF=$(ip route | grep default | awk '{print $5}' | head -1)
    PRIMARY_IP=$(ip addr show "$PRIMARY_IF" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)

    # Proxmox version
    PVE_VERSION=$(pveversion | head -1 | cut -d'/' -f2)
}

display_host_info() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                         PROXMOX HOST STATISTICS                              ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Hostname and Version
    printf "${BOLD}%-20s${NC} %-30s ${BOLD}%-15s${NC} %s\n" \
        "Hostname:" "$(hostname)" \
        "Proxmox:" "$PVE_VERSION"

    printf "${BOLD}%-20s${NC} %-30s ${BOLD}%-15s${NC} %s\n" \
        "IP Address:" "$PRIMARY_IP" \
        "Uptime:" "$UPTIME"

    echo ""
    echo -e "${BOLD}${BLUE}CPU Information:${NC}"
    printf "  Model: %s\n" "$CPU_MODEL"
    printf "  Cores: %-10s Usage: " "$CPU_CORES"
    print_bar "$CPU_USAGE" 50
    printf " %.1f%%\n" "$CPU_USAGE"
    printf "  Load Average: %s\n" "$LOAD_AVG"

    echo ""
    echo -e "${BOLD}${BLUE}Memory Usage:${NC}"
    printf "  Total: %-10s Used: %-10s Free: %s\n" "$MEM_TOTAL" "$MEM_USED" "$MEM_FREE"
    printf "  Usage: "
    print_bar "$MEM_PERCENT" 50
    printf " %.1f%%\n" "$MEM_PERCENT"

    echo ""
    echo -e "${BOLD}${BLUE}Root Disk Usage:${NC}"
    printf "  Total: %-10s Used: %-10s Free: %s\n" "$DISK_TOTAL" "$DISK_USED" "$DISK_FREE"
    printf "  Usage: "
    print_bar "$DISK_PERCENT" 50
    printf " %s%%\n" "$DISK_PERCENT"

    if [[ "$STORAGE_TOTAL" != "N/A" ]]; then
        echo ""
        echo -e "${BOLD}${BLUE}Storage (local-lvm):${NC}"
        printf "  Total: %-10s Used: %-10s Avail: %s\n" "$STORAGE_TOTAL" "$STORAGE_USED" "$STORAGE_AVAIL"
        printf "  Usage: "
        print_bar "$STORAGE_PERCENT" 50
        printf " %.1f%%\n" "$STORAGE_PERCENT"
    fi

    echo ""
}

print_bar() {
    local percent=$1
    local width=$2
    local filled=$(printf "%.0f" "$(echo "$percent * $width / 100" | bc -l)")
    local empty=$((width - filled))

    # Color based on percentage
    local color=""
    if (( $(echo "$percent < 60" | bc -l) )); then
        color=$GREEN
    elif (( $(echo "$percent < 80" | bc -l) )); then
        color=$YELLOW
    else
        color=$RED
    fi

    echo -n "["
    echo -n -e "${color}"
    printf '%*s' "$filled" | tr ' ' '█'
    echo -n -e "${NC}"
    printf '%*s' "$empty" | tr ' ' '░'
    echo -n "]"
}

get_vm_stats() {
    # Get list of all VMs (both running and stopped)
    VM_LIST=$(qm list | tail -n +2)
}

display_vm_table() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                           VIRTUAL MACHINES                                   ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Table header
    printf "${BOLD}%-8s %-20s %-12s %-10s %-8s %-10s %-8s${NC}\n" \
        "VMID" "NAME" "STATUS" "MEMORY" "CPU" "DISK" "UPTIME"
    echo "────────────────────────────────────────────────────────────────────────────────"

    # Count VMs
    local running_count=0
    local stopped_count=0
    local template_count=0

    # Parse and display each VM
    if [[ -z "$VM_LIST" ]]; then
        echo "No VMs found"
    else
        while IFS= read -r line; do
            # Extract fields from qm list output
            VMID=$(echo "$line" | awk '{print $1}')
            STATUS=$(echo "$line" | awk '{print $2}')
            NAME=$(echo "$line" | awk '{print $3}')

            # Get additional VM details
            if [[ "$STATUS" == "running" ]]; then
                running_count=$((running_count + 1))

                # Get current stats for running VMs
                VM_MEM_CURRENT=$(qm status "$VMID" --verbose | grep "mem:" | awk '{printf "%.0f", $2/1024/1024}')
                VM_MEM_MAX=$(qm config "$VMID" | grep "^memory:" | awk '{print $2}')
                VM_CPU=$(qm status "$VMID" --verbose | grep "cpu:" | awk '{printf "%.1f%%", $2*100}')

                # Get uptime
                VM_PID=$(qm status "$VMID" --verbose | grep "pid:" | awk '{print $2}')
                if [[ -n "$VM_PID" ]] && [[ -d "/proc/$VM_PID" ]]; then
                    VM_UPTIME=$(ps -p "$VM_PID" -o etimes= 2>/dev/null | awk '{print $1}')
                    VM_UPTIME=$(format_uptime "$VM_UPTIME")
                else
                    VM_UPTIME="-"
                fi

                # Format memory
                MEM_STR="${VM_MEM_CURRENT}M/${VM_MEM_MAX}M"

                # Get disk size
                DISK_SIZE=$(qm config "$VMID" | grep -E "^(scsi|sata|virtio|ide)[0-9]:" | head -1 | grep -oP 'size=\K[^,]+' || echo "-")

                # Print with green status
                printf "${GREEN}%-8s${NC} %-20s ${GREEN}%-12s${NC} %-10s %-8s %-10s %-8s\n" \
                    "$VMID" "$NAME" "$STATUS" "$MEM_STR" "$VM_CPU" "$DISK_SIZE" "$VM_UPTIME"

            elif [[ "$STATUS" == "template" ]]; then
                template_count=$((template_count + 1))

                VM_MEM_MAX=$(qm config "$VMID" | grep "^memory:" | awk '{print $2}')
                DISK_SIZE=$(qm config "$VMID" | grep -E "^(scsi|sata|virtio|ide)[0-9]:" | head -1 | grep -oP 'size=\K[^,]+' || echo "-")

                # Print with blue status for templates
                printf "${BLUE}%-8s${NC} %-20s ${BLUE}%-12s${NC} %-10s %-8s %-10s %-8s\n" \
                    "$VMID" "$NAME" "$STATUS" "${VM_MEM_MAX}M" "-" "$DISK_SIZE" "-"

            else
                stopped_count=$((stopped_count + 1))

                VM_MEM_MAX=$(qm config "$VMID" | grep "^memory:" | awk '{print $2}')
                DISK_SIZE=$(qm config "$VMID" | grep -E "^(scsi|sata|virtio|ide)[0-9]:" | head -1 | grep -oP 'size=\K[^,]+' || echo "-")

                # Print with yellow/red status for stopped
                printf "${YELLOW}%-8s${NC} %-20s ${YELLOW}%-12s${NC} %-10s %-8s %-10s %-8s\n" \
                    "$VMID" "$NAME" "$STATUS" "${VM_MEM_MAX}M" "-" "$DISK_SIZE" "-"
            fi

        done <<< "$VM_LIST"
    fi

    echo "────────────────────────────────────────────────────────────────────────────────"
    printf "${BOLD}Summary:${NC} "
    printf "${GREEN}Running: %d${NC}  " "$running_count"
    printf "${YELLOW}Stopped: %d${NC}  " "$stopped_count"
    printf "${BLUE}Templates: %d${NC}  " "$template_count"
    printf "Total: %d\n" "$((running_count + stopped_count + template_count))"
    echo ""
}

format_uptime() {
    local seconds=$1

    if [[ -z "$seconds" ]] || [[ "$seconds" == "0" ]]; then
        echo "-"
        return
    fi

    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))

    if [[ $days -gt 0 ]]; then
        echo "${days}d ${hours}h"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

display_legend() {
    echo -e "${BOLD}Legend:${NC}"
    echo -e "  ${GREEN}Green${NC}  = Running VM"
    echo -e "  ${YELLOW}Yellow${NC} = Stopped VM"
    echo -e "  ${BLUE}Blue${NC}   = Template"
    echo ""
    echo -e "${BOLD}Quick Actions:${NC}"
    echo "  Start VM:    qm start <VMID>"
    echo "  Stop VM:     qm shutdown <VMID>"
    echo "  Console:     qm terminal <VMID>"
    echo "  VM Config:   qm config <VMID>"
    echo ""
}

display_footer() {
    echo -e "${CYAN}Last updated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"

    if [[ "$WATCH_MODE" == "true" ]]; then
        echo -e "${YELLOW}Press Ctrl+C to exit watch mode${NC}"
    fi
}

################################################################################
# Main Display Function
################################################################################

show_dashboard() {
    if [[ "$WATCH_MODE" == "true" ]]; then
        clear
    fi

    get_host_stats
    display_host_info

    get_vm_stats
    display_vm_table

    display_legend
    display_footer
}

################################################################################
# Main Script
################################################################################

main() {
    # Check for watch mode
    WATCH_MODE="false"
    REFRESH_INTERVAL=5

    if [[ "$1" == "--watch" ]] || [[ "$1" == "-w" ]]; then
        WATCH_MODE="true"
        if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
            REFRESH_INTERVAL=$2
        fi
    fi

    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "Proxmox Task Manager"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --watch, -w [interval]   Watch mode with auto-refresh (default: 5 seconds)"
        echo "  --help, -h               Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                       Show dashboard once"
        echo "  $0 --watch              Watch mode with 5 second refresh"
        echo "  $0 --watch 10           Watch mode with 10 second refresh"
        echo ""
        exit 0
    fi

    if [[ "$WATCH_MODE" == "true" ]]; then
        # Watch mode - continuous refresh
        while true; do
            show_dashboard
            sleep "$REFRESH_INTERVAL"
        done
    else
        # Single display
        show_dashboard
    fi
}

main "$@"
