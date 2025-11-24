#!/bin/bash
################################################################################
# SSH Configuration Master Script
#
# Interactive script to configure SSH with various options:
# 1. Import GitHub SSH keys
# 2. Enable/disable key-based authentication
# 3. Enable/disable password authentication
# 4. Configure root login
#
# This provides flexible SSH configuration with safety checks and backups.
################################################################################

set -e

# Configuration - Synology or standard Linux paths
if [ -d "/volume1/scripts/logs" ]; then
    LOG_DIR="/volume1/scripts/logs"
else
    LOG_DIR="/var/log"
fi

LOG_FILE="${LOG_DIR}/ssh-config-master.log"
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="${LOG_DIR}/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################

log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
}

print_log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE"
    exit 1
}

success() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

warn() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

info() {
    echo -e "${CYAN}$1${NC}"
}

################################################################################
# Helper Functions
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
            LOG_FILE="/tmp/ssh-config-master.log"
            BACKUP_FILE="/tmp/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
            warn "Using /tmp for logs instead"
        }
    fi
}

backup_sshd_config() {
    print_log "Backing up current sshd_config to $BACKUP_FILE"
    cp "$SSHD_CONFIG" "$BACKUP_FILE" || error "Failed to backup sshd_config"
    cp "$SSHD_CONFIG" "${LOG_DIR}/sshd_config.before_master" || true
    success "Backed up sshd_config successfully"
}

test_sshd_config() {
    print_log "Testing SSH configuration"
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
    print_log "Restarting SSH service"

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

################################################################################
# GitHub Key Import
################################################################################

import_github_keys() {
    local github_user="$1"

    print_log "Importing SSH keys from GitHub user: $github_user"

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
    local github_keys_url="https://github.com/$github_user.keys"
    info "Fetching keys from: $github_keys_url"

    local keys=$(curl -fsSL "$github_keys_url" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$keys" ]; then
        error "Failed to fetch SSH keys from GitHub: $github_keys_url"
    fi

    # Count keys
    local key_count=$(echo "$keys" | grep -c "^ssh-" || echo "0")

    if [ "$key_count" -eq 0 ]; then
        error "No SSH keys found for GitHub user: $github_user"
    fi

    info "Found $key_count SSH key(s) for user $github_user"

    # Write keys to authorized_keys
    echo "$keys" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chown root:root /root/.ssh/authorized_keys

    success "SSH keys imported successfully to /root/.ssh/authorized_keys"
}

################################################################################
# SSH Configuration Functions
################################################################################

configure_pubkey_auth() {
    local enable="$1"

    if [ "$enable" = "yes" ]; then
        print_log "Enabling public key authentication"

        if grep -q "^PubkeyAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
        elif grep -q "^#PubkeyAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
        else
            echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
        fi

        success "Public key authentication enabled"
    else
        print_log "Disabling public key authentication"

        if grep -q "^PubkeyAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication no/' "$SSHD_CONFIG"
        elif grep -q "^#PubkeyAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication no/' "$SSHD_CONFIG"
        else
            echo "PubkeyAuthentication no" >> "$SSHD_CONFIG"
        fi

        warn "Public key authentication disabled"
    fi
}

configure_password_auth() {
    local enable="$1"

    if [ "$enable" = "yes" ]; then
        print_log "Enabling password authentication"

        if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        elif grep -q "^#PasswordAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        else
            echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
        fi

        # Also enable challenge-response for password auth
        if grep -q "^ChallengeResponseAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' "$SSHD_CONFIG"
        elif grep -q "^KbdInteractiveAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' "$SSHD_CONFIG"
        fi

        success "Password authentication enabled"
    else
        print_log "Disabling password authentication"

        if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
        elif grep -q "^#PasswordAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
        else
            echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
        fi

        # Also disable challenge-response
        if grep -q "^ChallengeResponseAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
        elif grep -q "^KbdInteractiveAuthentication" "$SSHD_CONFIG"; then
            sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "$SSHD_CONFIG"
        fi

        warn "Password authentication disabled"
    fi
}

configure_root_login() {
    print_log "Configuring root login"

    if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
    elif grep -q "^#PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
    else
        echo "PermitRootLogin yes" >> "$SSHD_CONFIG"
    fi

    success "Root login enabled"
}

################################################################################
# User Interaction
################################################################################

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [ "$default" = "y" ]; then
        read -p "$(echo -e ${CYAN}${prompt}${NC} [Y/n]: )" response
        response=${response,,} # to lowercase
        [[ -z "$response" || "$response" =~ ^y ]] && echo "yes" || echo "no"
    else
        read -p "$(echo -e ${CYAN}${prompt}${NC} [y/N]: )" response
        response=${response,,} # to lowercase
        [[ "$response" =~ ^y ]] && echo "yes" || echo "no"
    fi
}

prompt_github_username() {
    local username
    read -p "$(echo -e ${CYAN}Enter GitHub username${NC} [default: dihoyt]: )" username
    username=${username:-dihoyt}
    echo "$username"
}

print_banner() {
    echo ""
    echo -e "${BOLD}${BLUE}================================================================================${NC}"
    echo -e "${BOLD}${BLUE}                    SSH Configuration Master Script${NC}"
    echo -e "${BOLD}${BLUE}================================================================================${NC}"
    echo ""
}

print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo -e "${BOLD}${GREEN}                    Configuration Summary${NC}"
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo ""
    log "===== Configuration Summary ====="
    log "Hostname: $(hostname)"
    log "GitHub User: ${GITHUB_USER:-N/A}"
    log "Public Key Auth: ${ENABLE_PUBKEY_AUTH}"
    log "Password Auth: ${ENABLE_PASSWORD_AUTH}"
    log "Root Login: ENABLED"
    log "Backup: $BACKUP_FILE"
    log "Log file: $LOG_FILE"

    info "Hostname: $(hostname)"
    info "GitHub User: ${GITHUB_USER:-N/A}"
    info "Public Key Authentication: ${ENABLE_PUBKEY_AUTH}"
    info "Password Authentication: ${ENABLE_PASSWORD_AUTH}"
    info "Root Login: ENABLED"
    info ""
    info "Backup saved to: $BACKUP_FILE"
    info "Log file: $LOG_FILE"
    echo ""
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo -e "${BOLD}${GREEN}                    Configuration Complete!${NC}"
    echo -e "${BOLD}${GREEN}================================================================================${NC}"
    echo ""
}

################################################################################
# Main Script Execution
################################################################################

main() {
    # Create log directory
    create_log_directory

    # Start logging
    log "===== SSH Configuration Master Script Started ====="
    log "Running as: $(whoami)"
    log "Hostname: $(hostname)"
    log "Date: $(date)"

    # Print banner
    print_banner

    # Check root privileges
    check_root

    # Ask if user wants to import GitHub keys
    local import_keys=$(prompt_yes_no "Import SSH keys from GitHub?" "y")

    if [ "$import_keys" = "yes" ]; then
        GITHUB_USER=$(prompt_github_username)
        log "User chose to import GitHub keys for: $GITHUB_USER"
    fi

    # Ask about key-based authentication
    ENABLE_PUBKEY_AUTH=$(prompt_yes_no "Enable key-based authentication?" "y")
    log "Key-based auth: $ENABLE_PUBKEY_AUTH"

    # Ask about password authentication
    ENABLE_PASSWORD_AUTH=$(prompt_yes_no "Enable password authentication?" "y")
    log "Password auth: $ENABLE_PASSWORD_AUTH"

    # Safety check
    if [ "$ENABLE_PUBKEY_AUTH" = "no" ] && [ "$ENABLE_PASSWORD_AUTH" = "no" ]; then
        error "You cannot disable both key-based AND password authentication! You would be locked out."
    fi

    echo ""
    warn "About to configure SSH with the following settings:"
    info "  Import GitHub keys: $import_keys"
    [ "$import_keys" = "yes" ] && info "  GitHub username: $GITHUB_USER"
    info "  Public key auth: $ENABLE_PUBKEY_AUTH"
    info "  Password auth: $ENABLE_PASSWORD_AUTH"
    info "  Root login: ENABLED"
    echo ""

    local confirm=$(prompt_yes_no "Continue with these settings?" "y")
    if [ "$confirm" != "yes" ]; then
        echo "Aborted by user."
        exit 0
    fi

    echo ""

    # Backup current configuration
    backup_sshd_config

    # Import GitHub keys if requested
    if [ "$import_keys" = "yes" ]; then
        import_github_keys "$GITHUB_USER"
    fi

    # Configure authentication methods
    configure_pubkey_auth "$ENABLE_PUBKEY_AUTH"
    configure_password_auth "$ENABLE_PASSWORD_AUTH"
    configure_root_login

    # Test configuration
    test_sshd_config

    # Restart SSH service
    restart_ssh_service

    # Print summary
    print_summary

    log "===== Script Completed Successfully ====="

    exit 0
}

# Run main function
main "$@"