#!/bin/bash
# Quick sync script - minimal version

REPO_URL="https://github.com/dihoyt/claudeai.git"
TARGET_DIR="/volume1/scripts"
TEMP_DIR="/tmp/claudeai-sync"

# Clean up and clone
rm -rf "$TEMP_DIR"
git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

# Debug: Show contents and wait for confirmation
echo ""
echo "========================================="
echo "Repository cloned to: $TEMP_DIR"
echo "========================================="
echo "Contents of temp directory:"
ls -lah "$TEMP_DIR"
echo ""
echo "Contents of scripts folder:"
ls -lah "$TEMP_DIR/scripts" 2>/dev/null || echo "Scripts folder not found!"
echo ""
echo "========================================="
read -p "Continue with sync? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Sync cancelled. Cleaning up..."
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Sync scripts folder
rsync -av --delete "$TEMP_DIR/scripts/" "$TARGET_DIR/"

# Cleanup
rm -rf "$TEMP_DIR"

echo "Sync complete"
