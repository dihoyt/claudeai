#!/bin/bash
################################################################################
# SSH Password Authentication Helper Script
#
# This script:
# 1. Backs up current sshd_config to /volume1/scripts/logs/
# 2. Re-enables password authentication
# 3. Restarts SSH service
################################################################################

set -e

# Configuration
LOG_DIR="/volume1/scripts/logs"
LOG_FILE="${LOG_DIR}/ssh-enable-password.log"

log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "[ERROR] $1" >&2
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Configuration
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_DIR="/volume1/scripts/logs"
BACKUP_FILE="${BACKUP_DIR}/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

# Create log/backup directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" 2>/dev/null || {
        echo "[ERROR] Failed to create log directory: $LOG_DIR" >&2
        exit 1
    }
fi

# Start logging
log "===== SSH Password Authentication Script Started ====="
log "Running as: $(whoami)"
log "Hostname: $(hostname)"

# Backup current sshd_config
log "Backing up sshd_config to $BACKUP_FILE"
cp "$SSHD_CONFIG" "$BACKUP_FILE" || error "Failed to backup sshd_config"

# Also keep a latest copy
cp "$SSHD_CONFIG" "${BACKUP_DIR}/sshd_config.latest" || error "Failed to create latest backup"

# Enable password authentication
log "Enabling password authentication"
if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
    # Line exists, update it
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
else
    # Line doesn't exist or is commented, add it
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    # If still not found, append it
    if ! grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
        echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
    fi
fi

# Test sshd configuration
log "Testing SSH configuration"
sshd -t || error "SSH configuration test failed. Restoring backup..."

# Restart SSH service
log "Restarting SSH service"
if systemctl is-active --quiet ssh; then
    systemctl restart ssh || systemctl restart sshd || error "Failed to restart SSH service"
elif systemctl is-active --quiet sshd; then
    systemctl restart sshd || error "Failed to restart SSH service"
else
    error "SSH service not found (tried 'ssh' and 'sshd')"
fi

# Verify password authentication is enabled
if grep -q "^PasswordAuthentication yes" "$SSHD_CONFIG"; then
    log "Password authentication successfully enabled"
    log "Backup saved to: $BACKUP_FILE"
    log "Latest backup: ${BACKUP_DIR}/sshd_config.latest"
    log "===== Script Completed Successfully ====="
    exit 0
else
    error "Failed to enable password authentication"
fi