#!/bin/bash

################################################################################
# Proxmox VM Creation from Existing Disk Script
#
# Creates a VM configuration pointing to an existing disk image.
# Useful for recovering VMs or importing existing disks.
#
# Usage: sudo ./create-vm-from-disk.sh
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
# Disk Detection
################################################################################

list_available_disks() {
    echo ""
    highlight "Available LVM Thin Volumes:"
    echo "================================================================================"
    lvs --noheadings -o lv_name,lv_size,vg_name | grep -E "vm-|base-" | while read -r lv size vg; do
        echo "  $vg/$lv (${size})"
    done
    echo "================================================================================"
    echo ""
}

get_vm_id() {
    while true; do
        read -p "Enter VM ID for new VM: " VM_ID

        # Validate VM ID is a number
        if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
            warn "Invalid VM ID. Please enter a numeric ID."
            continue
        fi

        # Check if VM ID already exists
        if qm status "$VM_ID" &>/dev/null; then
            warn "VM ID $VM_ID already exists. Please choose a different ID."
            continue
        fi

        log "Using VM ID: $VM_ID"
        break
    done
}

get_vm_name() {
    read -p "Enter VM name: " VM_NAME

    if [ -z "$VM_NAME" ]; then
        warn "VM name cannot be empty. Using default: vm-$VM_ID"
        VM_NAME="vm-$VM_ID"
    fi

    log "VM name: $VM_NAME"
}

get_disk_info() {
    echo ""
    info "Enter disk information in format: storage:disk-name"
    info "Example: local-lvm:vm-100-disk-0"
    echo ""

    while true; do
        read -p "Disk location: " DISK_LOCATION

        # Parse storage and disk
        if [[ "$DISK_LOCATION" =~ ^([^:]+):(.+)$ ]]; then
            STORAGE="${BASH_REMATCH[1]}"
            DISK_NAME="${BASH_REMATCH[2]}"

            # Verify storage exists
            if ! pvesm status | grep -q "^$STORAGE "; then
                warn "Storage '$STORAGE' not found. Please try again."
                continue
            fi

            # For LVM, verify disk exists
            if [[ "$DISK_NAME" =~ ^(vm-|base-) ]]; then
                if ! lvs | grep -q "$DISK_NAME"; then
                    warn "Disk '$DISK_NAME' not found. Please try again."
                    continue
                fi
            fi

            log "Disk: $DISK_LOCATION"
            break
        else
            warn "Invalid format. Use: storage:disk-name"
        fi
    done
}

get_disk_size() {
    echo ""
    info "Enter disk size (e.g., 32G, 256G)"
    read -p "Disk size: " DISK_SIZE

    if [ -z "$DISK_SIZE" ]; then
        warn "Disk size cannot be empty. Using default: 32G"
        DISK_SIZE="32G"
    fi

    log "Disk size: $DISK_SIZE"
}

get_vm_specs() {
    echo ""
    info "Enter VM specifications (press Enter for defaults):"
    echo ""

    # CPU Cores
    read -p "CPU cores [2]: " CPU_CORES
    CPU_CORES=${CPU_CORES:-2}

    # Memory
    read -p "Memory (MB) [4096]: " MEMORY
    MEMORY=${MEMORY:-4096}

    # Network bridge
    read -p "Network bridge [vmbr0]: " NET_BRIDGE
    NET_BRIDGE=${NET_BRIDGE:-vmbr0}

    # VLAN tag
    read -p "VLAN tag (leave empty for none): " VLAN_TAG
    if [[ -n "$VLAN_TAG" ]] && [[ ! "$VLAN_TAG" =~ ^[0-9]+$ ]]; then
        warn "Invalid VLAN tag. VLAN must be a number. Disabling VLAN."
        VLAN_TAG=""
    fi

    # OS Type
    echo ""
    info "OS Type options: l26 (Linux), win10 (Windows 10), win11 (Windows 11)"
    read -p "OS type [l26]: " OS_TYPE
    OS_TYPE=${OS_TYPE:-l26}

    # Template
    read -p "Is this a template? [y/N]: " IS_TEMPLATE
    if [[ "$IS_TEMPLATE" =~ ^[Yy]$ ]]; then
        TEMPLATE="1"
    else
        TEMPLATE="0"
    fi

    echo ""
    log "CPU Cores: $CPU_CORES"
    log "Memory: ${MEMORY}MB"
    log "Network: $NET_BRIDGE"
    if [ -n "$VLAN_TAG" ]; then
        log "VLAN: $VLAN_TAG"
    else
        log "VLAN: None"
    fi
    log "OS Type: $OS_TYPE"
    log "Template: $([[ "$TEMPLATE" == "1" ]] && echo "Yes" || echo "No")"
}

################################################################################
# VM Creation
################################################################################

create_vm_config() {
    log "Creating VM configuration file..."

    local config_file="/etc/pve/qemu-server/${VM_ID}.conf"

    # Generate random MAC address
    MAC_ADDR=$(printf 'BC:24:11:%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

    # Generate random UUIDs
    SMBIOS_UUID=$(uuidgen)
    VMGENID=$(uuidgen)

    # Build network configuration
    if [ -n "$VLAN_TAG" ]; then
        NET_CONFIG="virtio=${MAC_ADDR},bridge=${NET_BRIDGE},firewall=1,tag=${VLAN_TAG}"
    else
        NET_CONFIG="virtio=${MAC_ADDR},bridge=${NET_BRIDGE},firewall=1"
    fi

    # Create config file
    cat > "$config_file" << EOF
agent: 1
boot: order=scsi0
cores: $CPU_CORES
cpu: x86-64-v2-AES
ide2: none,media=cdrom
memory: $MEMORY
meta: creation-qemu=9.0.2,ctime=$(date +%s)
name: $VM_NAME
net0: ${NET_CONFIG}
numa: 0
ostype: $OS_TYPE
scsi0: ${DISK_LOCATION},size=${DISK_SIZE}
scsihw: virtio-scsi-single
smbios1: uuid=${SMBIOS_UUID}
sockets: 1
vmgenid: ${VMGENID}
EOF

    # Add template flag if needed
    if [ "$TEMPLATE" == "1" ]; then
        echo "template: 1" >> "$config_file"
    fi

    log "VM configuration created: $config_file"
}

verify_vm() {
    echo ""
    log "Verifying VM configuration..."

    if qm status "$VM_ID" &>/dev/null; then
        log "VM $VM_ID created successfully"

        echo ""
        highlight "VM Configuration:"
        echo "================================================================================"
        qm config "$VM_ID"
        echo "================================================================================"
        echo ""
        return 0
    else
        error "Failed to create VM $VM_ID"
        return 1
    fi
}

show_summary() {
    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}VM Created Successfully!${NC}"
    echo "================================================================================"
    echo ""
    echo "VM Details:"
    echo "  VM ID:        $VM_ID"
    echo "  Name:         $VM_NAME"
    echo "  Disk:         $DISK_LOCATION"
    echo "  CPU:          $CPU_CORES cores"
    echo "  Memory:       ${MEMORY}MB"
    echo "  Network:      $NET_BRIDGE"
    if [ -n "$VLAN_TAG" ]; then
        echo "  VLAN:         $VLAN_TAG"
    fi
    echo "  Template:     $([[ "$TEMPLATE" == "1" ]] && echo "Yes" || echo "No")"
    echo ""
    echo "================================================================================"
    echo ""
    echo "Next steps:"
    echo ""
    if [ "$TEMPLATE" == "1" ]; then
        echo "  • Clone this template to create new VMs"
        echo "  • View in Proxmox web UI"
    else
        echo "  • Start the VM: qm start $VM_ID"
        echo "  • View console in Proxmox web UI"
        echo "  • Adjust settings if needed: Hardware tab in web UI"
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
    echo "                    Proxmox VM Creation from Existing Disk"
    echo "================================================================================"
    echo ""
    echo "This script will create a VM configuration using an existing disk."
    echo ""
    echo "================================================================================"

    # Check prerequisites
    check_root

    # Show available disks
    list_available_disks

    # Gather information
    get_vm_id
    get_vm_name
    get_disk_info
    get_disk_size
    get_vm_specs

    # Confirm
    echo ""
    highlight "Review Configuration:"
    echo "================================================================================"
    echo "  VM ID:        $VM_ID"
    echo "  VM Name:      $VM_NAME"
    echo "  Disk:         $DISK_LOCATION ($DISK_SIZE)"
    echo "  CPU:          $CPU_CORES cores"
    echo "  Memory:       ${MEMORY}MB"
    echo "  Network:      $NET_BRIDGE"
    if [ -n "$VLAN_TAG" ]; then
        echo "  VLAN:         $VLAN_TAG"
    else
        echo "  VLAN:         None"
    fi
    echo "  OS Type:      $OS_TYPE"
    echo "  Template:     $([[ "$TEMPLATE" == "1" ]] && echo "Yes" || echo "No")"
    echo "================================================================================"
    echo ""

    read -p "Create VM with these settings? [Y/n]: " CONFIRM
    echo ""

    if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
        warn "VM creation cancelled by user"
        exit 0
    fi

    # Create VM
    create_vm_config

    # Verify
    verify_vm

    # Show summary
    show_summary
}

main "$@"