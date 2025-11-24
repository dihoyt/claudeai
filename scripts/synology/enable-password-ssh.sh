#!/bin/bash
################################################################################
# SSH Password Access Restoration Script
# For Synology NAS or any Linux system
#
# This script reverses changes made by ssh-gh-dih-root.sh:
# 1. Backs up current sshd_config to /volume1/scripts/logs/ (or /tmp/ if not Synology)
# 2. Re-enables password authentication
# 3. Allows root login with password
# 4. Restarts SSH service
#
# Usage: Run as a scheduled task or directly with root privileges
################################################################################

set -e

# Configuration - Synology or standard Linux paths
if [ -d "/volume1/scripts/logs" ]; then
    LOG_DIR="/volume1/scripts/logs"
else
    LOG_DIR="/tmp"
fi

LOG_FILE="${LOG_DIR}/ssh-restore-password-access.log"
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="${LOG_DIR}/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

################################################################################
# Logging Functions
################################################################################

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

success() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo "$msg" >> "$LOG_FILE"
}

################################################################################
# Main Functions
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

create_log_directory() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            LOG_DIR="/tmp"
            LOG_FILE="/tmp/ssh-restore-password-access.log"
            BACKUP_FILE="/tmp/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
        }
    fi
}

backup_sshd_config() {
    log "Backing up current sshd_config to $BACKUP_FILE"
    cp "$SSHD_CONFIG" "$BACKUP_FILE" || error "Failed to backup sshd_config"

    # Also keep a latest copy
    cp "$SSHD_CONFIG" "${LOG_DIR}/sshd_config.before_restore" || true

    success "Backed up sshd_config successfully"
}

restore_password_authentication() {
    log "Restoring password authentication settings"

    # Enable password authentication
    if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        log "Updated existing PasswordAuthentication to yes"
    elif grep -q "^#PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        log "Uncommented and enabled PasswordAuthentication"
    else
        echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
        log "Added PasswordAuthentication yes"
    fi

    # Allow root login with password
    if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
        log "Updated existing PermitRootLogin to yes"
    elif grep -q "^#PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
        log "Uncommented and enabled PermitRootLogin"
    else
        echo "PermitRootLogin yes" >> "$SSHD_CONFIG"
        log "Added PermitRootLogin yes"
    fi

    # Enable challenge-response authentication (common on Synology)
    if grep -q "^ChallengeResponseAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' "$SSHD_CONFIG"
        log "Enabled ChallengeResponseAuthentication"
    elif grep -q "^KbdInteractiveAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' "$SSHD_CONFIG"
        log "Enabled KbdInteractiveAuthentication"
    fi

    success "Password authentication settings restored"
}

test_sshd_config() {
    log "Testing SSH configuration"

    if sshd -t 2>/dev/null; then
        success "SSH configuration test passed"
        return 0
    else
        error "SSH configuration test failed. Config may be invalid. Restoring backup..."
        cp "$BACKUP_FILE" "$SSHD_CONFIG"
        return 1
    fi
}

restart_ssh_service() {
    log "Restarting SSH service"

    # Try different service names (Synology uses 'sshd', Ubuntu may use 'ssh')
    if systemctl restart sshd 2>/dev/null; then
        success "SSH service (sshd) restarted successfully"
    elif systemctl restart ssh 2>/dev/null; then
        success "SSH service (ssh) restarted successfully"
    elif /etc/init.d/sshd restart 2>/dev/null; then
        success "SSH service restarted via init.d"
    elif synoservicectl --restart sshd 2>/dev/null; then
        success "SSH service restarted via Synology synoservicectl"
    else
        error "Failed to restart SSH service. Please restart manually."
    fi
}

verify_settings() {
    log "Verifying settings in sshd_config"

    local password_auth=$(grep "^PasswordAuthentication" "$SSHD_CONFIG" | tail -1)
    local root_login=$(grep "^PermitRootLogin" "$SSHD_CONFIG" | tail -1)

    log "Current settings:"
    log "  $password_auth"
    log "  $root_login"

    if grep -q "^PasswordAuthentication yes" "$SSHD_CONFIG" && grep -q "^PermitRootLogin yes" "$SSHD_CONFIG"; then
        success "Password authentication is enabled and root login is permitted"
        return 0
    else
        error "Settings verification failed. Please check $LOG_FILE"
        return 1
    fi
}

print_summary() {
    log "===== Restoration Summary ====="
    log "Hostname: $(hostname)"
    log "Backup saved to: $BACKUP_FILE"
    log "Log file: $LOG_FILE"
    log "Password authentication: ENABLED"
    log "Root login: ENABLED"
    log "===== Script Completed Successfully ====="
}

################################################################################
# Main Script Execution
################################################################################

main() {
    # Start logging
    create_log_directory
    log "===== SSH Password Access Restoration Script Started ====="
    log "Running as: $(whoami)"
    log "Hostname: $(hostname)"
    log "Date: $(date)"

    # Check root privileges
    check_root

    # Backup current configuration
    backup_sshd_config

    # Restore password authentication
    restore_password_authentication

    # Test configuration
    test_sshd_config

    # Restart SSH service
    restart_ssh_service

    # Verify settings
    verify_settings

    # Print summary
    print_summary

    # Exit successfully
    exit 0
}

# Run main function
main "$@"