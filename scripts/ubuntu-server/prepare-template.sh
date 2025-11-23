#!/bin/bash

################################################################################
# Ubuntu VM Template Preparation Script
# For Proxmox with Cloud-Init Support
#
# This script cleans an Ubuntu installation to prepare it as a Proxmox template.
# It removes machine-specific information, logs, and prepares the system for
# cloud-init provisioning.
#
# Usage: Run this script on a fresh Ubuntu installation before converting
#        the VM to a template in Proxmox.
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
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

################################################################################
# Cleaning Functions
################################################################################

install_cloud_init() {
    log "Installing cloud-init and QEMU guest agent..."

    apt-get update
    apt-get install -y cloud-init qemu-guest-agent

    # Enable QEMU guest agent
    systemctl enable qemu-guest-agent

    log "Cloud-init and QEMU guest agent installed"
}

configure_cloud_init() {
    log "Configuring cloud-init..."

    # Create cloud-init configuration
    cat > /etc/cloud/cloud.cfg.d/99-pve.cfg <<'EOF'
# Proxmox cloud-init configuration
datasource_list: [NoCloud, ConfigDrive]

# Preserve hostname set by cloud-init
preserve_hostname: false

# Manage /etc/hosts
manage_etc_hosts: true

# Configure cloud-init modules
cloud_init_modules:
  - migrator
  - seed_random
  - bootcmd
  - write-files
  - growpart
  - resizefs
  - disk_setup
  - mounts
  - set_hostname
  - update_hostname
  - update_etc_hosts
  - ca-certs
  - rsyslog
  - users-groups
  - ssh

cloud_config_modules:
  - emit_upstart
  - snap
  - ssh-import-id
  - locale
  - set-passwords
  - grub-dpkg
  - apt-pipelining
  - apt-configure
  - ubuntu-advantage
  - ntp
  - timezone
  - disable-ec2-metadata
  - runcmd
  - byobu

cloud_final_modules:
  - package-update-upgrade-install
  - fan
  - landscape
  - lxd
  - ubuntu-drivers
  - write-files-deferred
  - puppet
  - chef
  - mcollective
  - salt-minion
  - reset_rmc
  - refresh_rmc_and_interface
  - rightscale_userdata
  - scripts-vendor
  - scripts-per-once
  - scripts-per-boot
  - scripts-per-instance
  - scripts-user
  - ssh-authkey-fingerprints
  - keys-to-console
  - phone-home
  - final-message
  - power-state-change

# System information
system_info:
  default_user:
    name: ubuntu
    lock_passwd: true
    gecos: Ubuntu
    groups: [adm, audio, cdrom, dialout, dip, floppy, lxd, netdev, plugdev, sudo, video]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    # Uncomment one of these options to automatically import SSH keys:
    # Option 1: Import from GitHub (recommended)
    ssh_import_id: [gh:dihoyt]
    # Option 2: Import from Launchpad
    # ssh_import_id: [lp:your-launchpad-username]
    # Option 3: Add specific key directly
    # ssh_authorized_keys:
    #   - ssh-rsa AAAAB3Nza... your-key-comment
  network:
    renderers: ['networkd', 'eni', 'sysconfig']
  package_mirrors:
    - arches: [default]
      failsafe:
        primary: http://archive.ubuntu.com/ubuntu
        security: http://security.ubuntu.com/ubuntu
EOF

    log "Cloud-init configuration created"
}

clean_cloud_init() {
    log "Cleaning cloud-init data..."

    # Remove cloud-init artifacts
    cloud-init clean --logs --seed

    # Remove cloud-init cache and logs
    rm -rf /var/lib/cloud/instances/*
    rm -rf /var/lib/cloud/instance
    rm -rf /var/lib/cloud/data

    log "Cloud-init data cleaned"
}

clean_network() {
    log "Cleaning network configuration..."

    # Remove persistent network device names
    rm -f /etc/udev/rules.d/70-persistent-net.rules

    # Remove network interface persistence
    if [ -d /etc/netplan ]; then
        # Backup existing netplan configs
        mkdir -p /root/netplan-backup
        cp /etc/netplan/*.yaml /root/netplan-backup/ 2>/dev/null || true

        # Create basic netplan config for cloud-init
        cat > /etc/netplan/00-installer-config.yaml <<'EOF'
# Cloud-init will manage network configuration
network:
  version: 2
  renderer: networkd
EOF
    fi

    # Clean DHCP leases
    rm -f /var/lib/dhcp/*

    log "Network configuration cleaned"
}

clean_ssh() {
    log "Cleaning SSH configuration..."

    # Remove SSH host keys (cloud-init will regenerate)
    rm -f /etc/ssh/ssh_host_*

    # Remove authorized_keys (cloud-init will set these)
    find /home -name authorized_keys -delete
    find /root -name authorized_keys -delete

    # Remove known_hosts
    find /home -name known_hosts -delete
    find /root -name known_hosts -delete

    log "SSH configuration cleaned"
}

clean_machine_id() {
    log "Cleaning machine ID..."

    # Truncate machine-id (will be regenerated on first boot)
    truncate -s 0 /etc/machine-id

    # Link for systemd
    if [ -f /var/lib/dbus/machine-id ]; then
        rm -f /var/lib/dbus/machine-id
        ln -s /etc/machine-id /var/lib/dbus/machine-id
    fi

    log "Machine ID cleaned"
}

clean_logs() {
    log "Cleaning log files..."

    # Clean system logs
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
    find /var/log -type f -name "*.gz" -delete
    find /var/log -type f -name "*.1" -delete
    find /var/log -type f -name "*.old" -delete

    # Clean journal logs
    journalctl --rotate
    journalctl --vacuum-time=1s

    # Clean apt logs
    rm -rf /var/log/apt/*

    # Clean installer logs
    rm -rf /var/log/installer/*

    log "Log files cleaned"
}

clean_temporary_files() {
    log "Cleaning temporary files..."

    # Clean /tmp
    rm -rf /tmp/*
    rm -rf /var/tmp/*

    # Clean apt cache
    apt-get clean
    apt-get autoclean

    # Clean package lists
    rm -rf /var/lib/apt/lists/*

    log "Temporary files cleaned"
}

clean_user_data() {
    log "Cleaning user data..."

    # Clean bash history
    history -c
    find /home -name ".bash_history" -delete
    find /root -name ".bash_history" -delete

    # Clean user cache
    find /home -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true
    find /root -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true

    # Clean user temp files
    find /home -type f -name ".viminfo" -delete
    find /root -type f -name ".viminfo" -delete

    log "User data cleaned"
}

clean_package_manager() {
    log "Cleaning package manager..."

    # Remove packages that are no longer needed
    apt-get autoremove -y

    # Clean apt cache
    apt-get clean

    log "Package manager cleaned"
}

disable_swap() {
    log "Disabling and removing swap..."

    # Turn off swap
    swapoff -a

    # Remove swap file if it exists
    if [ -f /swap.img ]; then
        rm -f /swap.img
    fi

    # Comment out swap entries in fstab
    sed -i '/swap/s/^/#/' /etc/fstab

    log "Swap disabled and removed"
}

zero_free_space() {
    log "Zeroing free space (this may take a while)..."

    # This helps with template compression
    # Fill free space with zeros, then delete
    dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
    rm -f /EMPTY

    log "Free space zeroed"
}

update_system() {
    log "Updating system packages..."

    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y

    log "System updated"
}

install_common_tools() {
    log "Installing common tools..."

    apt-get install -y \
        curl \
        wget \
        vim \
        nano \
        git \
        htop \
        net-tools \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https

    log "Common tools installed"
}

create_info_file() {
    log "Creating template information file..."

    cat > /root/TEMPLATE_INFO.txt <<EOF
================================================================================
Ubuntu Template for Proxmox with Cloud-Init
Created: $(date)
================================================================================

TEMPLATE INFORMATION:
---------------------
OS Version: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Hostname: $(hostname)

INSTALLED COMPONENTS:
---------------------
- Cloud-init
- QEMU Guest Agent
- Common system tools

NEXT STEPS IN PROXMOX:
----------------------
1. Shut down this VM:
   shutdown -h now

2. In Proxmox shell, convert VM to template:
   qm template <VMID>

3. When creating VMs from this template:
   - Clone the template
   - Configure cloud-init settings in Proxmox GUI:
     * User credentials
     * SSH keys
     * Network settings (IP/CIDR, Gateway, DNS)
     * DNS domain and search domain
   - Start the VM

CLOUD-INIT CONFIGURATION:
-------------------------
Default user: ubuntu
User will be created by cloud-init with:
- SSH access via public key
- Sudo access (NOPASSWD)
- Password authentication disabled by default

NETWORK:
--------
Network configuration is managed by cloud-init.
Set network details in Proxmox GUI under Cloud-Init tab.

SSH:
----
SSH host keys will be generated on first boot.
Add your SSH public key via Proxmox Cloud-Init tab.

CUSTOMIZATION:
--------------
You can customize cloud-init behavior by:
1. Editing /etc/cloud/cloud.cfg.d/99-pve.cfg before templating
2. Using cloud-init user-data via Proxmox

MAINTENANCE:
------------
To update the template:
1. Clone template to a new VM
2. Boot and apply updates
3. Run this script again
4. Convert to template
5. Delete old template

VERIFICATION:
-------------
After booting a cloned VM, verify cloud-init ran successfully:
  sudo cloud-init status
  sudo cloud-init query -a

================================================================================
EOF

    chmod 644 /root/TEMPLATE_INFO.txt
    log "Template information file created at /root/TEMPLATE_INFO.txt"
}

################################################################################
# Main Preparation Flow
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "          Ubuntu VM Template Preparation for Proxmox + Cloud-Init"
    echo "================================================================================"
    echo ""
    echo "This script will:"
    echo "  1. Install cloud-init and QEMU guest agent"
    echo "  2. Configure cloud-init for Proxmox"
    echo "  3. Clean machine-specific data:"
    echo "     - Network configuration"
    echo "     - SSH host keys"
    echo "     - Machine ID"
    echo "     - Log files"
    echo "     - Temporary files"
    echo "     - User data and history"
    echo "  4. Update system packages"
    echo "  5. Install common tools"
    echo ""
    echo "WARNING: This will remove SSH keys, logs, and machine-specific data!"
    echo ""
    echo "================================================================================"
    echo ""

    read -p "Press Enter to continue or Ctrl+C to cancel..."
    echo ""

    check_root

    log "Starting template preparation..."

    # Update and install cloud-init
    update_system
    install_common_tools
    install_cloud_init
    configure_cloud_init

    # Clean the system
    clean_cloud_init
    clean_network
    clean_ssh
    clean_machine_id
    clean_logs
    clean_temporary_files
    clean_user_data
    clean_package_manager
    disable_swap

    # Create info file
    create_info_file

    # Final step - zero free space (optional but recommended)
    echo ""
    read -p "Zero free space for better compression? (recommended but slow) [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        zero_free_space
    else
        warn "Skipping free space zeroing"
    fi

    echo ""
    echo "================================================================================"
    echo "                    Template Preparation Complete!"
    echo "================================================================================"
    echo ""
    echo -e "${GREEN}✓${NC} VM is ready to be converted to a template"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Review template information:"
    echo -e "   ${YELLOW}cat /root/TEMPLATE_INFO.txt${NC}"
    echo ""
    echo "2. Shut down this VM:"
    echo -e "   ${YELLOW}shutdown -h now${NC}"
    echo ""
    echo "3. In Proxmox shell, convert to template:"
    echo -e "   ${YELLOW}qm template <VMID>${NC}"
    echo ""
    echo "4. Configure cloud-init defaults in Proxmox GUI:"
    echo "   - VM -> Cloud-Init tab"
    echo "   - Set default SSH key, DNS, etc."
    echo ""
    echo "5. Clone the template to create new VMs"
    echo ""
    echo "================================================================================"
    echo ""

    # Optional automatic shutdown
    read -p "Shut down VM now to convert to template? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Shutting down VM in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        shutdown -h now
    else
        echo ""
        echo -e "${YELLOW}VM will remain running.${NC}"
        echo -e "Shut down manually when ready: ${YELLOW}shutdown -h now${NC}"
        echo ""
    fi
}

main "$@"