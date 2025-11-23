#!/bin/bash

################################################################################
# SSH GitHub Root Access Configuration Script
#
# Imports SSH keys from GitHub user dihoyt and configures SSH to allow root
# login via authorized_keys only, disabling password authentication.

#
# Usage: ./ssh-gh-dih-root.sh
################################################################################

set -e

# Configuration REPLACE dihoyt with desired GitHub username!!! Otherwise, i'll have access to your vm's with my keys :)
GITHUB_USER="dihoyt"

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

################################################################################
# Validation Functions
################################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
    fi
}

################################################################################
# GitHub SSH Key Import
################################################################################

import_github_keys() {
    log "Importing SSH keys from GitHub user: $GITHUB_USER"

    # Create .ssh directory if it doesn't exist
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    # Backup existing authorized_keys if it exists
    if [ -f /root/.ssh/authorized_keys ]; then
        cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup.$(date +%Y%m%d_%H%M%S)
        log "Backed up existing authorized_keys"
    fi

    # Fetch SSH keys from GitHub
    GITHUB_KEYS_URL="https://github.com/$GITHUB_USER.keys"
    KEYS=$(curl -fsSL "$GITHUB_KEYS_URL")

    if [ $? -ne 0 ] || [ -z "$KEYS" ]; then
        error "Failed to fetch SSH keys from GitHub: $GITHUB_KEYS_URL"
    fi

    # Count keys
    KEY_COUNT=$(echo "$KEYS" | grep -c "^ssh-")
    log "Found $KEY_COUNT SSH key(s) for user $GITHUB_USER"

    # Write keys to authorized_keys
    echo "$KEYS" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chown root:root /root/.ssh/authorized_keys

    log "SSH keys imported successfully"
}

################################################################################
# SSH Configuration Functions
################################################################################

configure_sshd() {
    log "Configuring SSH daemon for key-only authentication"

    SSHD_CONFIG="/etc/ssh/sshd_config"

    # Backup original sshd_config
    if [ ! -f "${SSHD_CONFIG}.backup" ]; then
        cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backed up original sshd_config"
    fi

    # Configure SSH settings - PermitRootLogin
    if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONFIG"
    else
        echo "PermitRootLogin prohibit-password" >> "$SSHD_CONFIG"
    fi

    # Disable password authentication
    if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    else
        echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
    fi

    # Enable public key authentication
    if grep -q "^PubkeyAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
    else
        echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
    fi

    # Disable challenge-response authentication
    if grep -q "^ChallengeResponseAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
    elif grep -q "^KbdInteractiveAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "$SSHD_CONFIG"
    else
        echo "ChallengeResponseAuthentication no" >> "$SSHD_CONFIG"
    fi

    log "SSH configuration updated"
}

test_sshd_config() {
    log "Testing SSH configuration"

    if sshd -t; then
        log "SSH configuration test passed"
        return 0
    else
        error "SSH configuration test failed"
        return 1
    fi
}

restart_sshd() {
    log "Restarting SSH service"

    if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
        log "SSH service restarted successfully"
    else
        error "Failed to restart SSH service"
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    # Check if running as root
    check_root

    # Import GitHub SSH keys
    import_github_keys

    # Configure SSH daemon
    configure_sshd

    # Test configuration
    test_sshd_config

    # Restart SSH service
    restart_sshd

    # Done
    log "SSH configured for key-only root access from gh:$GITHUB_USER on $(hostname)"
}

main "$@"