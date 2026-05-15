#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# Script: upload_investigation.sh
# Purpose: Uploads a research/investigation folder to Google Drive using rclone.
#          It automatically converts Markdown files to editable Google Docs,
#          while preserving the original .md files in an 'md_originals' subfolder.
# -----------------------------------------------------------------------------

RCLONE_BIN="$HOME/.local/bin/rclone"

# Determine source directory and investigation name
SOURCE_DIR="${1:-$(pwd)}"
INVESTIGATION_NAME=$(basename "$SOURCE_DIR")
BASE_REMOTE="gdrive:Investigations"
TARGET_DIR="$BASE_REMOTE/$INVESTIGATION_NAME"

echo "🚀 Starting upload for investigation: $INVESTIGATION_NAME"
echo "📂 Source: $SOURCE_DIR"
echo "☁️  Target: $TARGET_DIR"

if [ ! -f "$RCLONE_BIN" ]; then
    echo "❌ Error: rclone not found at $RCLONE_BIN"
    exit 1
fi

# 1. Convert and upload Markdown files as Google Docs
echo "📄 1/3: Converting and uploading Markdown files as Google Docs..."
$RCLONE_BIN copy "$SOURCE_DIR" "$TARGET_DIR" \
    --include "*.md" \
    --drive-import-formats md \
    --drive-allow-import-name-change \
    --ignore-errors

# 2. Upload original Markdown files
echo "📝 2/3: Preserving original Markdown files in md_originals/..."
$RCLONE_BIN copy "$SOURCE_DIR" "$TARGET_DIR/md_originals" \
    --include "*.md" \
    --ignore-errors

# 3. Upload all other files (images, assets, etc.)
echo "📦 3/3: Uploading other assets and files..."
$RCLONE_BIN copy "$SOURCE_DIR" "$TARGET_DIR" \
    --exclude "*.md" \
    --exclude ".git/**" \
    --exclude ".vscode/**" \
    --exclude "node_modules/**" \
    --ignore-errors

echo "✅ Investigation successfully uploaded to Google Drive!"
