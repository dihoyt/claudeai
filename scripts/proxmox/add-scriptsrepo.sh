#!/bin/bash
# Configure NFS mount for /scripts

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# NFS mount configuration
NFS_SERVER="10.50.1.100:/volume1/scripts"
MOUNT_POINT="/scripts"
MOUNT_OPTIONS="nfs defaults,_netdev 0 0"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================="
log "Starting NFS Mount Configuration"
log "========================================="

# Install nfs-common if not already installed
if ! dpkg -l | grep -q nfs-common; then
    log "Installing nfs-common package..."
    apt-get update
    apt-get install -y nfs-common
    log "nfs-common installed"
else
    log "nfs-common already installed"
fi

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    log "Creating mount point: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
else
    log "Mount point $MOUNT_POINT already exists"
fi

# Check if NFS mount already exists in fstab
if grep -q "$NFS_SERVER" /etc/fstab; then
    log "NFS mount already exists in /etc/fstab"
else
    log "Adding NFS mount to /etc/fstab"
    echo "$NFS_SERVER $MOUNT_POINT $MOUNT_OPTIONS" >> /etc/fstab
    log "NFS mount added to /etc/fstab"
fi

# Unmount if already mounted (to ensure clean remount)
if mountpoint -q "$MOUNT_POINT"; then
    log "Unmounting existing mount at $MOUNT_POINT"
    umount "$MOUNT_POINT"
fi

# Mount the NFS share
log "Mounting NFS share..."
if mount "$MOUNT_POINT"; then
    log "NFS mount successful!"
    log "Verifying mount..."
    if mountpoint -q "$MOUNT_POINT"; then
        log "✓ $MOUNT_POINT is mounted"
        df -h "$MOUNT_POINT" | tail -n 1
    else
        log "✗ Mount verification failed"
        exit 1
    fi
else
    log "✗ Failed to mount NFS share"
    log "Please check:"
    log "  1. NFS server is accessible: ping 10.50.1.100"
    log "  2. NFS share is exported: showmount -e 10.50.1.100"
    log "  3. Firewall allows NFS traffic"
    exit 1
fi

log "========================================="
log "NFS Mount Configuration Complete!"
log "Mount: $NFS_SERVER -> $MOUNT_POINT"
log "========================================="
