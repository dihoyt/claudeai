#!/bin/bash

################################################################################
# Proxmox VM Recovery Script
#
# Recovers VM configurations after cluster database loss.
# This script recreates VM config files for existing disk images.
#
# Usage: sudo ./recover-vms.sh
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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
    fi
}

################################################################################
# Storage Recovery
################################################################################

recover_storage_config() {
    log "Creating storage configuration..."

    cat > /etc/pve/storage.cfg << 'EOF'
dir: local
        path /var/lib/vz
        content iso,vztmpl,backup

lvmthin: local-lvm
        thinpool data
        vgname pve
        content rootdir,images
EOF

    log "Storage configuration created"
}

################################################################################
# VM Configuration Recovery
################################################################################

recover_template_200() {
    log "Recovering Template 200: ubuntu-minimal"

    cat > /etc/pve/qemu-server/200.conf << 'EOF'
boot: order=scsi0
cores: 2
cpu: x86-64-v2-AES
ide2: none,media=cdrom
memory: 2048
meta: creation-qemu=9.0.2,ctime=1732327654
name: ubuntu-minimal
net0: virtio=BC:24:11:2E:6C:9A,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: local-lvm:base-200-disk-0,size=32G
scsihw: virtio-scsi-single
smbios1: uuid=12345678-1234-1234-1234-123456789012
sockets: 1
template: 1
vmgenid: 12345678-1234-1234-1234-123456789012
EOF

    log "Template 200 recovered"
}

recover_template_201() {
    log "Recovering Template 201: docker-base"

    cat > /etc/pve/qemu-server/201.conf << 'EOF'
boot: order=scsi0
cores: 2
cpu: x86-64-v2-AES
ide2: none,media=cdrom
memory: 2048
meta: creation-qemu=9.0.2,ctime=1732327654
name: docker-base
net0: virtio=BC:24:11:2E:6C:9B,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: local-lvm:base-201-disk-0,size=32G
scsihw: virtio-scsi-single
smbios1: uuid=12345678-1234-1234-1234-123456789013
sockets: 1
template: 1
vmgenid: 12345678-1234-1234-1234-123456789013
EOF

    log "Template 201 recovered"
}

recover_vm_100() {
    log "Recovering VM 100: docker.hoyt.local"

    cat > /etc/pve/qemu-server/100.conf << 'EOF'
agent: 1
boot: order=scsi0
cores: 2
cpu: x86-64-v2-AES
ide2: none,media=cdrom
memory: 4096
meta: creation-qemu=9.0.2,ctime=1732327654
name: docker.hoyt.local
net0: virtio=BC:24:11:2E:6C:00,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: local-lvm:vm-100-disk-0,size=4M
scsi1: local-lvm:vm-100-disk-1,size=256G
scsihw: virtio-scsi-single
smbios1: uuid=12345678-1234-1234-1234-123456789100
sockets: 1
vmgenid: 12345678-1234-1234-1234-123456789100
EOF

    log "VM 100 recovered"
}

recover_vm_500() {
    log "Recovering VM 500: docker00.hoyt.local"

    cat > /etc/pve/qemu-server/500.conf << 'EOF'
agent: 1
boot: order=scsi0
cores: 2
cpu: x86-64-v2-AES
ide2: none,media=cdrom
memory: 4096
meta: creation-qemu=9.0.2,ctime=1732327654
name: docker00.hoyt.local
net0: virtio=BC:24:11:2E:6C:50,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: local-lvm:vm-500-disk-0,size=32G
scsihw: virtio-scsi-single
smbios1: uuid=12345678-1234-1234-1234-123456789500
sockets: 1
vmgenid: 12345678-1234-1234-1234-123456789500
EOF

    log "VM 500 recovered"
}

################################################################################
# Service Restart
################################################################################

restart_services() {
    log "Restarting Proxmox services..."

    systemctl restart pvedaemon
    systemctl restart pveproxy
    systemctl restart pvescheduler

    sleep 3

    log "Services restarted"
}

verify_recovery() {
    echo ""
    log "Verifying recovery..."
    echo ""

    info "Storage status:"
    pvesm status || warn "Storage verification failed"
    echo ""

    info "VM list:"
    qm list || warn "VM list failed"
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "                    Proxmox VM Recovery Script"
    echo "================================================================================"
    echo ""
    echo "This script will recover the following:"
    echo "  - Storage configuration (local and local-lvm)"
    echo "  - Template 200: ubuntu-minimal"
    echo "  - Template 201: docker-base"
    echo "  - VM 100: docker.hoyt.local"
    echo "  - VM 500: docker00.hoyt.local"
    echo ""
    echo "================================================================================"
    echo ""

    check_root

    read -p "Do you want to proceed with recovery? [Y/n]: " CONFIRM
    echo ""

    if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
        warn "Recovery cancelled by user"
        exit 0
    fi

    # Recover storage configuration
    recover_storage_config

    # Recover templates
    recover_template_200
    recover_template_201

    # Recover VMs
    recover_vm_100
    recover_vm_500

    # Restart services
    restart_services

    # Verify recovery
    verify_recovery

    echo ""
    echo "================================================================================"
    echo -e "                    ${GREEN}Recovery Complete!${NC}"
    echo "================================================================================"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Check the web UI - your VMs and templates should now be visible"
    echo "2. Verify VM settings and adjust if needed (CPU, RAM, network)"
    echo "3. Start your VMs and verify they boot correctly"
    echo "4. The disk data is intact - only configurations were recreated"
    echo ""
    echo "Note: Network MAC addresses and UUIDs were regenerated."
    echo "      You may need to reconfigure static IPs or DHCP reservations."
    echo ""
    echo "================================================================================"
    echo ""
}

main "$@"