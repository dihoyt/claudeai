#!/bin/bash
# Import SSH keys from GitHub and authorize them for SSH access

# GitHub username to import keys from
GITHUB_USER="dihoyt"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "========================================="
log "Importing SSH keys from GitHub"
log "========================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log "Running as root - will configure keys for root user"
    USER_HOME="/root"
    CURRENT_USER="root"
else
    log "Running as regular user - will configure keys for current user"
    USER_HOME="$HOME"
    CURRENT_USER="$USER"
fi

# Create .ssh directory if it doesn't exist
SSH_DIR="$USER_HOME/.ssh"
if [ ! -d "$SSH_DIR" ]; then
    log "Creating $SSH_DIR directory"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# Path to authorized_keys file
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Backup existing authorized_keys if it exists
if [ -f "$AUTHORIZED_KEYS" ]; then
    BACKUP_FILE="$AUTHORIZED_KEYS.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backing up existing authorized_keys to $BACKUP_FILE"
    cp "$AUTHORIZED_KEYS" "$BACKUP_FILE"
fi

# Fetch SSH keys from GitHub
log "Fetching SSH keys for GitHub user: $GITHUB_USER"
GITHUB_KEYS_URL="https://github.com/$GITHUB_USER.keys"

# Download keys
KEYS=$(curl -fsSL "$GITHUB_KEYS_URL")

if [ $? -ne 0 ] || [ -z "$KEYS" ]; then
    log " Failed to fetch SSH keys from GitHub"
    log "  URL attempted: $GITHUB_KEYS_URL"
    log "  Please check:"
    log "    1. GitHub username is correct"
    log "    2. User has public SSH keys on GitHub"
    log "    3. Internet connection is available"
    exit 1
fi

# Count keys
KEY_COUNT=$(echo "$KEYS" | grep -c "^ssh-")
log "Found $KEY_COUNT SSH key(s) for user $GITHUB_USER"

# Create or overwrite authorized_keys with the new keysa
echo "$KEYS" > "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

# Set proper ownership
if [[ $EUID -eq 0 ]]; then
    chown root:root "$AUTHORIZED_KEYS"
else
    chown "$CURRENT_USER:$CURRENT_USER" "$AUTHORIZED_KEYS"
fi

log "  SSH keys imported successfully"
log "  Location: $AUTHORIZED_KEYS"
log "  Keys imported: $KEY_COUNT"

# Display the keys (truncated for security)
log ""
log "Imported keys (fingerprints):"
while IFS= read -r key; do
    if [[ $key == ssh-* ]]; then
        # Extract key type and first few characters
        KEY_TYPE=$(echo "$key" | awk '{print $1}')
        KEY_FINGERPRINT=$(echo "$key" | awk '{print substr($2, 1, 20)"..."}')
        log "  - $KEY_TYPE $KEY_FINGERPRINT"
    fi
done <<< "$KEYS"

log ""
log "========================================="
log "SSH Key Authorization Complete!"
log "You can now SSH using keys from gh:$GITHUB_USER"
log "========================================="
