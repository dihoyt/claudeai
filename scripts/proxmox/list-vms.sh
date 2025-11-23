#!/bin/bash

################################################################################
# Proxmox VM List Script
#
# Displays a formatted list of all VMs with their details.
#
# Usage: ./list-vms.sh [OPTIONS]
# Options:
#   --running    Show only running VMs
#   --stopped    Show only stopped VMs
#   --templates  Show only templates
#   --no-templates  Exclude templates (default)
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Configuration
################################################################################

FILTER_STATUS=""
SHOW_TEMPLATES=false
EXCLUDE_TEMPLATES=true

################################################################################
# Helper Functions
################################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --running)
                FILTER_STATUS="running"
                shift
                ;;
            --stopped)
                FILTER_STATUS="stopped"
                shift
                ;;
            --templates)
                SHOW_TEMPLATES=true
                EXCLUDE_TEMPLATES=false
                shift
                ;;
            --no-templates)
                EXCLUDE_TEMPLATES=true
                SHOW_TEMPLATES=false
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --running        Show only running VMs"
    echo "  --stopped        Show only stopped VMs"
    echo "  --templates      Show only templates"
    echo "  --no-templates   Exclude templates (default)"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # List all VMs (excluding templates)"
    echo "  $0 --running          # List only running VMs"
    echo "  $0 --templates        # List only templates"
}

get_vm_info() {
    local vmid=$1
    local config=$(qm config "$vmid" 2>/dev/null)
    local status=$(qm status "$vmid" 2>/dev/null | awk '{print $2}')

    # Get basic info
    local name=$(echo "$config" | grep "^name:" | cut -d' ' -f2)
    local memory=$(echo "$config" | grep "^memory:" | cut -d' ' -f2)
    local cores=$(echo "$config" | grep "^cores:" | cut -d' ' -f2)
    local is_template=$(echo "$config" | grep "^template:" | cut -d' ' -f2)

    # Get disk size (first disk found)
    local disk_size=$(echo "$config" | grep -E "^(scsi|sata|virtio|ide)[0-9]:" | head -1 | grep -oP 'size=[^,]+' | cut -d= -f2)

    # Get IP address if VM is running and has qemu-guest-agent
    local ip_address=""
    if [ "$status" = "running" ]; then
        ip_address=$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
                     grep -oP '"ip-address":\s*"\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=")' | \
                     grep -v "127.0.0.1" | head -1)
    fi

    # Determine type
    local vm_type="VM"
    if [ "$is_template" = "1" ]; then
        vm_type="TEMPLATE"
    fi

    # Apply filters
    if [ "$EXCLUDE_TEMPLATES" = true ] && [ "$is_template" = "1" ]; then
        return 1
    fi

    if [ "$SHOW_TEMPLATES" = true ] && [ "$is_template" != "1" ]; then
        return 1
    fi

    if [ -n "$FILTER_STATUS" ] && [ "$status" != "$FILTER_STATUS" ]; then
        return 1
    fi

    # Format status with color
    local status_display
    case $status in
        running)
            status_display="${GREEN}running${NC}"
            ;;
        stopped)
            status_display="${YELLOW}stopped${NC}"
            ;;
        *)
            status_display="${RED}${status}${NC}"
            ;;
    esac

    # Format type with color
    local type_display
    if [ "$vm_type" = "TEMPLATE" ]; then
        type_display="${CYAN}TEMPLATE${NC}"
    else
        type_display="VM"
    fi

    # Output formatted line
    printf "%-6s %-20s %-15s %-10s %-8s %-6s %-10s %s\n" \
        "$vmid" \
        "$name" \
        "$(echo -e "$status_display")" \
        "$memory" \
        "$cores" \
        "${disk_size:-N/A}" \
        "$type_display" \
        "${ip_address:-}"

    return 0
}

list_vms() {
    # Print header
    echo ""
    echo "================================================================================"

    if [ -n "$FILTER_STATUS" ]; then
        echo -e "                    ${BLUE}Proxmox VMs (${FILTER_STATUS})${NC}"
    elif [ "$SHOW_TEMPLATES" = true ]; then
        echo -e "                    ${BLUE}Proxmox Templates${NC}"
    else
        echo -e "                    ${BLUE}Proxmox VMs${NC}"
    fi

    echo "================================================================================"
    echo ""

    # Print column headers
    printf "%-6s %-20s %-15s %-10s %-8s %-6s %-10s %s\n" \
        "VMID" "NAME" "STATUS" "MEMORY" "CORES" "DISK" "TYPE" "IP ADDRESS"
    echo "--------------------------------------------------------------------------------"

    # Get list of all VMs
    local vm_count=0
    local running_count=0
    local stopped_count=0
    local template_count=0

    while read -r vmid; do
        if [ -n "$vmid" ]; then
            if get_vm_info "$vmid"; then
                ((vm_count++))

                # Count by status
                local status=$(qm status "$vmid" 2>/dev/null | awk '{print $2}')
                local is_template=$(qm config "$vmid" 2>/dev/null | grep "^template:" | cut -d' ' -f2)

                if [ "$is_template" = "1" ]; then
                    ((template_count++))
                elif [ "$status" = "running" ]; then
                    ((running_count++))
                elif [ "$status" = "stopped" ]; then
                    ((stopped_count++))
                fi
            fi
        fi
    done < <(qm list | tail -n +2 | awk '{print $1}')

    # Print summary
    echo "--------------------------------------------------------------------------------"

    if [ "$SHOW_TEMPLATES" = true ]; then
        echo "Total templates: $vm_count"
    elif [ -n "$FILTER_STATUS" ]; then
        echo "Total $FILTER_STATUS: $vm_count"
    else
        echo "Running: $running_count | Stopped: $stopped_count | Total: $vm_count"
    fi

    echo "================================================================================"
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse command line arguments
    parse_args "$@"

    # List VMs
    list_vms
}

main "$@"
