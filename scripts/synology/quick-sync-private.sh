#!/bin/bash
################################################################################
# Quick Sync Script for Private Repository
#
# This script syncs a private Git repository to /volume1/scripts
# Supports multiple authentication methods:
# 1. GitHub Personal Access Token (recommended)
# 2. SSH key (if configured)
# 3. Username/password (legacy)
#
# Usage:
#   1. Set your GitHub token as an environment variable:
#      export GITHUB_TOKEN="your_token_here"
#   2. Run the script:
#      bash quick-sync-private.sh
#
# Alternative: Edit GITHUB_TOKEN below directly (less secure)
################################################################################

set -e

# Configuration
REPO_URL="https://github.com/dihoyt/claudeai.git"
TARGET_DIR="/volume1/scripts"
TEMP_DIR="/tmp/claudeai-sync"
LOG_FILE="/volume1/scripts/logs/quick-sync-private.log"
COMMIT_CACHE_FILE="/volume1/scripts/.last-sync-commit"

# GitHub credentials (choose one method)
# Method 1: Personal Access Token (recommended - set as environment variable)
# Create token at: https://github.com/settings/tokens
# Required scopes: repo (for private repos)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Method 2: Username and password (deprecated by GitHub)
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_PASS="${GITHUB_PASS:-}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################

log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${msg}${NC}"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
}

warn() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

info() {
    echo -e "${BLUE}$1${NC}"
}

################################################################################
# Authentication Setup
################################################################################

setup_auth_url() {
    local base_url="$1"

    # Extract repo path from URL
    local repo_path=$(echo "$base_url" | sed 's|https://github.com/||' | sed 's|.git||')

    if [ -n "$GITHUB_TOKEN" ]; then
        # Use Personal Access Token
        log "Using GitHub Personal Access Token for authentication"
        echo "https://${GITHUB_TOKEN}@github.com/${repo_path}.git"
    elif [ -n "$GITHUB_USER" ] && [ -n "$GITHUB_PASS" ]; then
        # Use username/password (deprecated)
        warn "Using username/password authentication (deprecated by GitHub)"
        echo "https://${GITHUB_USER}:${GITHUB_PASS}@github.com/${repo_path}.git"
    else
        # Try without authentication (will fail for private repos)
        warn "No authentication credentials provided"
        info "Set GITHUB_TOKEN environment variable or edit the script"
        info "Create token at: https://github.com/settings/tokens"
        echo "$base_url"
    fi
}

check_git_installed() {
    if ! command -v git &> /dev/null; then
        error "Git is not installed. Please install git first."
    fi
}

################################################################################
# Sync Check Functions
################################################################################

get_remote_commit() {
    local auth_url="$1"

    log "Checking remote repository for latest commit..."

    # Get the latest commit hash from remote without cloning
    local remote_commit=$(git ls-remote "$auth_url" HEAD 2>/dev/null | awk '{print $1}')

    if [ -z "$remote_commit" ]; then
        error "Failed to fetch remote commit hash. Check credentials and network."
    fi

    echo "$remote_commit"
}

get_local_commit() {
    if [ -f "$COMMIT_CACHE_FILE" ]; then
        cat "$COMMIT_CACHE_FILE"
    else
        echo ""
    fi
}

save_local_commit() {
    local commit="$1"
    echo "$commit" > "$COMMIT_CACHE_FILE"
    log "Saved commit hash: $commit"
}

check_sync_needed() {
    local remote_commit="$1"
    local local_commit="$2"

    if [ -z "$local_commit" ]; then
        log "No previous sync found - sync needed"
        return 0  # Sync needed
    fi

    if [ "$remote_commit" = "$local_commit" ]; then
        log "Repository is up to date (commit: ${remote_commit:0:7})"
        info "✓ No sync needed - already at latest commit"
        return 1  # No sync needed
    else
        log "Repository has updates"
        log "  Local:  ${local_commit:0:7}"
        log "  Remote: ${remote_commit:0:7}"
        info "Updates available - sync needed"
        return 0  # Sync needed
    fi
}

################################################################################
# Main Sync Functions
################################################################################

cleanup_temp() {
    if [ -d "$TEMP_DIR" ]; then
        log "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

clone_repository() {
    local auth_url="$1"
    local remote_commit="$2"

    log "Cloning repository..."
    info "Repository: $REPO_URL"
    info "Target: $TARGET_DIR"
    info "Commit: ${remote_commit:0:7}"

    # Clean up any existing temp directory
    cleanup_temp

    # Clone with depth 1 (shallow clone for faster sync)
    if git clone --depth 1 "$auth_url" "$TEMP_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        log "Repository cloned successfully"
    else
        error "Failed to clone repository. Check credentials and repository access."
    fi
}

sync_scripts() {
    log "Syncing scripts to $TARGET_DIR"

    if [ ! -d "$TEMP_DIR/scripts" ]; then
        error "Scripts directory not found in repository"
    fi

    # Create target directory if it doesn't exist
    mkdir -p "$TARGET_DIR"

    # Sync scripts folder (delete files that no longer exist in repo)
    if rsync -av --delete "$TEMP_DIR/scripts/" "$TARGET_DIR/" 2>&1 | tee -a "$LOG_FILE"; then
        log "Scripts synced successfully"
    else
        error "Failed to sync scripts"
    fi
}

set_permissions() {
    log "Setting permissions"

    # Set directory permissions
    chmod -R 755 "$TARGET_DIR" 2>/dev/null || warn "Could not set directory permissions (this may be normal on NFS)"

    # Make all .sh files executable
    find "$TARGET_DIR" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || warn "Could not set execute permissions (this may be normal on NFS)"

    log "Permissions set"
}

print_summary() {
    local remote_commit="$1"

    echo ""
    log "===== Sync Summary ====="
    log "Repository: $REPO_URL"
    log "Target Directory: $TARGET_DIR"
    log "Current Commit: ${remote_commit:0:7}"
    log "Script Files: $(find "$TARGET_DIR" -type f -name "*.sh" 2>/dev/null | wc -l)"
    log "Total Files: $(find "$TARGET_DIR" -type f 2>/dev/null | wc -l)"
    log "Disk Usage: $(du -sh "$TARGET_DIR" 2>/dev/null | cut -f1)"
    log "Log File: $LOG_FILE"
    log "===== Sync Complete ====="
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    log "===== Quick Sync Private Repository Started ====="

    # Check git is installed
    check_git_installed

    # Setup authenticated URL
    local auth_url=$(setup_auth_url "$REPO_URL")

    # Check remote commit
    local remote_commit=$(get_remote_commit "$auth_url")
    local local_commit=$(get_local_commit)

    # Check if sync is needed
    if ! check_sync_needed "$remote_commit" "$local_commit"; then
        log "===== No Sync Needed - Exiting ====="
        exit 0
    fi

    # Sync is needed - proceed
    log "Proceeding with sync..."

    # Clone repository
    clone_repository "$auth_url" "$remote_commit"

    # Sync scripts
    sync_scripts

    # Set permissions
    set_permissions

    # Save the commit hash for next time
    save_local_commit "$remote_commit"

    # Cleanup
    cleanup_temp

    # Print summary
    print_summary "$remote_commit"
}

# Run main function
main "$@"