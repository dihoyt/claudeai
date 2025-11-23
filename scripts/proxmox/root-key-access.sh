#!/bin/bash

################################################################################
# SSH Root Key Access Configuration Script
#
# Configures SSH to allow root login via authorized_keys only, disabling
# password authentication for enhanced security.
#
# Usage: ./root-key-access.sh [public_key_file]
#        If no public key file is provided, prompts for the key
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

################################################################################
# Validation Functions
################################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
    fi
}

################################################################################
# SSH Configuration Functions
################################################################################

get_public_key() {
    # Get public key from authorized_keys if it exists
    if [ -f /root/.ssh/authorized_keys ] && [ -s /root/.ssh/authorized_keys ]; then
        log "Using existing authorized_keys"
        return 0
    fi

    error "No authorized_keys found. Please run authorize-git-keys.sh first"
}

setup_authorized_keys() {
    log "Verifying authorized_keys permissions..."

    # Ensure proper permissions
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys

    log "Permissions verified"
}

configure_sshd() {
    log "Configuring SSH daemon for key-only authentication..."

    SSHD_CONFIG="/etc/ssh/sshd_config"

    # Backup original sshd_config
    if [ ! -f "${SSHD_CONFIG}.backup" ]; then
        cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backed up original sshd_config"
    fi

    # Configure SSH settings
    # PermitRootLogin yes (with key only due to password auth being disabled)
    if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONFIG"
    else
        echo "PermitRootLogin prohibit-password" >> "$SSHD_CONFIG"
    fi
    log "Set PermitRootLogin to prohibit-password"

    # Disable password authentication
    if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    else
        echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
    fi
    log "Disabled password authentication"

    # Enable public key authentication (usually default, but make sure)
    if grep -q "^PubkeyAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
    else
        echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
    fi
    log "Enabled public key authentication"

    # Disable challenge-response authentication
    if grep -q "^ChallengeResponseAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
    elif grep -q "^KbdInteractiveAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "$SSHD_CONFIG"
    else
        echo "ChallengeResponseAuthentication no" >> "$SSHD_CONFIG"
    fi
    log "Disabled challenge-response authentication"
}

test_sshd_config() {
    log "Testing SSH configuration..."

    if sshd -t; then
        log "SSH configuration test passed"
        return 0
    else
        error "SSH configuration test failed! Not restarting SSH service."
        return 1
    fi
}

restart_sshd() {
    log "Restarting SSH service..."

    if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
        log "SSH service restarted successfully"
    else
        error "Failed to restart SSH service"
    fi
}

show_summary() {
    log "SSH configured for key-only root access on $(hostname)"
}

################################################################################
# Main Script
################################################################################

main() {
    # Check if running as root
    check_root

    # Verify authorized_keys exists
    get_public_key

    # Setup authorized_keys permissions
    setup_authorized_keys

    # Configure SSH daemon
    configure_sshd

    # Test configuration
    test_sshd_config

    # Restart SSH service
    restart_sshd

    # Show summary
    show_summary
}

main "$@"