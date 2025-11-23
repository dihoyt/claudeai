#!/bin/bash
# Quick sync script - minimal version

REPO_URL="https://github.com/dihoyt/claudeai.git"
TARGET_DIR="/volume1/scripts"
TEMP_DIR="/tmp/claudeai-sync"

# Clean up and clone
rm -rf "$TEMP_DIR"
git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

# Sync scripts folder
rsync -av --delete "$TEMP_DIR/scripts/" "$TARGET_DIR/"

# Set permissions
chmod -R 777 "$TARGET_DIR"
find "$TARGET_DIR" -type f -name "*.sh" -exec chmod +x {} \;

# Cleanup
rm -rf "$TEMP_DIR"

echo "Sync complete"
