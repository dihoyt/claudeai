#!/bin/bash

# Synology NAS Git Repository Sync Script
# Keeps a local folder synchronized with the scripts folder from a git repository
# Repository: https://github.com/dihoyt/claudeai/

# Configuration
REPO_URL="https://github.com/dihoyt/claudeai.git"
REPO_FOLDER="scripts"
TARGET_DIR="/volume1/scripts"  # Modify this to your desired location on Synology
TEMP_DIR="/tmp/claudeai-sync"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if git is installed
if ! command -v git &> /dev/null; then
    log_error "Git is not installed. Please install Git using Synology Package Center."
    exit 1
fi

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    log_info "Creating target directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# Clean up temp directory if it exists
if [ -d "$TEMP_DIR" ]; then
    log_info "Cleaning up temporary directory..."
    rm -rf "$TEMP_DIR"
fi

# Clone repository to temp directory
log_info "Cloning repository..."
if git clone --depth 1 "$REPO_URL" "$TEMP_DIR"; then
    log_info "Repository cloned successfully"
else
    log_error "Failed to clone repository"
    exit 1
fi

# Check if scripts folder exists in the repository
if [ ! -d "$TEMP_DIR/$REPO_FOLDER" ]; then
    log_error "Scripts folder not found in repository"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Sync the scripts folder to target directory
log_info "Syncing scripts folder to $TARGET_DIR..."
rsync -av --delete "$TEMP_DIR/$REPO_FOLDER/" "$TARGET_DIR/"

if [ $? -eq 0 ]; then
    log_info "Sync completed successfully"
else
    log_error "Sync failed"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up temp directory
log_info "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

log_info "Done! Scripts are up to date at $TARGET_DIR"