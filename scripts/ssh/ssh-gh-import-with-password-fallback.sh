#!/bin/bash
################################################################################
# SSH GitHub Key Import with Password Fallback
#
# This script:
# 1. Imports SSH keys from a GitHub user
# 2. Configures SSH to allow root login
# 3. Enables BOTH key-based AND password authentication (fallback)
# 4. Backs up configs and logs everything
#
# Usage: ./ssh-gh-import-with-password-fallback.sh [github_username]
################################################################################

set -e

# Configuration - Synology or standard Linux paths
if [ -d "/volume1/scripts/logs" ]; then
    LOG_DIR="/volume1/scripts/logs"
else
    LOG_DIR="/var/log"
fi

LOG_FILE="${LOG_DIR}/ssh-gh-import.log"
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="${LOG_DIR}/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

# Default GitHub username (change this to your username)
GITHUB_USER="${1:-dihoyt}"

################################################################################
# Logging Functions
################################################################################

log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo "$msg" | tee -a "$LOG_FILE" >&2
    exit 1
}

success() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

warn() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo "$msg" | tee -a "$LOG_FILE"
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
            LOG_FILE="/tmp/ssh-gh-import.log"
            BACKUP_FILE="/tmp/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
            warn "Using /tmp for logs instead"
        }
    fi
}

import_github_keys() {
    log "Importing SSH keys from GitHub user: $GITHUB_USER"

    # Create .ssh directory if it doesn't exist
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    # Backup existing authorized_keys if it exists
    if [ -f /root/.ssh/authorized_keys ]; then
        local backup_keys="/root/.ssh/authorized_keys.backup.$(date +%Y%m%d_%H%M%S)"
        cp /root/.ssh/authorized_keys "$backup_keys"
        log "Backed up existing authorized_keys to $backup_keys"
    fi

    # Fetch SSH keys from GitHub
    local github_keys_url="https://github.com/$GITHUB_USER.keys"
    log "Fetching keys from: $github_keys_url"

    local keys=$(curl -fsSL "$github_keys_url" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$keys" ]; then
        error "Failed to fetch SSH keys from GitHub: $github_keys_url"
    fi

    # Count keys
    local key_count=$(echo "$keys" | grep -c "^ssh-" || echo "0")

    if [ "$key_count" -eq 0 ]; then
        error "No SSH keys found for GitHub user: $GITHUB_USER"
    fi

    log "Found $key_count SSH key(s) for user $GITHUB_USER"

    # Write keys to authorized_keys
    echo "$keys" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chown root:root /root/.ssh/authorized_keys

    success "SSH keys imported successfully"
}

backup_sshd_config() {
    log "Backing up current sshd_config to $BACKUP_FILE"
    cp "$SSHD_CONFIG" "$BACKUP_FILE" || error "Failed to backup sshd_config"

    # Also keep a latest copy
    cp "$SSHD_CONFIG" "${LOG_DIR}/sshd_config.before_gh_import" || true

    success "Backed up sshd_config successfully"
}

configure_sshd_with_fallback() {
    log "Configuring SSH with key-based auth AND password fallback"

    # Allow root login (with both keys and passwords)
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

    # Enable public key authentication
    if grep -q "^PubkeyAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
        log "Enabled PubkeyAuthentication"
    elif grep -q "^#PubkeyAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
        log "Uncommented and enabled PubkeyAuthentication"
    else
        echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
        log "Added PubkeyAuthentication yes"
    fi

    # IMPORTANT: Keep password authentication enabled as fallback
    if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        log "Kept PasswordAuthentication enabled (fallback)"
    elif grep -q "^#PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        log "Uncommented and enabled PasswordAuthentication (fallback)"
    else
        echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
        log "Added PasswordAuthentication yes (fallback)"
    fi

    # Enable challenge-response authentication (for password fallback)
    if grep -q "^ChallengeResponseAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' "$SSHD_CONFIG"
        log "Enabled ChallengeResponseAuthentication"
    elif grep -q "^KbdInteractiveAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' "$SSHD_CONFIG"
        log "Enabled KbdInteractiveAuthentication"
    fi

    success "SSH configuration updated with key-based auth and password fallback"
}

test_sshd_config() {
    log "Testing SSH configuration"

    if sshd -t 2>/dev/null; then
        success "SSH configuration test passed"
        return 0
    else
        error "SSH configuration test failed. Restoring backup..."
        cp "$BACKUP_FILE" "$SSHD_CONFIG"
        return 1
    fi
}

restart_ssh_service() {
    log "Restarting SSH service"

    # Try different service restart methods
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

    local pubkey_auth=$(grep "^PubkeyAuthentication" "$SSHD_CONFIG" | tail -1)
    local password_auth=$(grep "^PasswordAuthentication" "$SSHD_CONFIG" | tail -1)
    local root_login=$(grep "^PermitRootLogin" "$SSHD_CONFIG" | tail -1)

    log "Current settings:"
    log "  $pubkey_auth"
    log "  $password_auth"
    log "  $root_login"

    if grep -q "^PubkeyAuthentication yes" "$SSHD_CONFIG" && \
       grep -q "^PasswordAuthentication yes" "$SSHD_CONFIG" && \
       grep -q "^PermitRootLogin yes" "$SSHD_CONFIG"; then
        success "All settings verified correctly"
        return 0
    else
        error "Settings verification failed. Please check $LOG_FILE"
        return 1
    fi
}

print_summary() {
    echo ""
    log "===== Configuration Summary ====="
    log "Hostname: $(hostname)"
    log "GitHub User: $GITHUB_USER"
    log "SSH Keys Imported: YES (to /root/.ssh/authorized_keys)"
    log "Key-based Authentication: ENABLED"
    log "Password Authentication: ENABLED (fallback)"
    log "Root Login: ENABLED"
    log ""
    log "Backup saved to: $BACKUP_FILE"
    log "Log file: $LOG_FILE"
    log ""
    log "You can now SSH in using:"
    log "  1. SSH key from GitHub (preferred)"
    log "  2. Password (fallback for troubleshooting)"
    log ""
    log "===== Script Completed Successfully ====="
    echo ""
}

################################################################################
# Main Script Execution
################################################################################

main() {
    # Start logging
    create_log_directory

    echo ""
    log "===== SSH GitHub Key Import with Password Fallback ====="
    log "Running as: $(whoami)"
    log "Hostname: $(hostname)"
    log "Date: $(date)"
    log "GitHub User: $GITHUB_USER"
    echo ""

    # Check root privileges
    check_root

    # Import GitHub SSH keys
    import_github_keys

    # Backup current configuration
    backup_sshd_config

    # Configure SSH with both key and password auth
    configure_sshd_with_fallback

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