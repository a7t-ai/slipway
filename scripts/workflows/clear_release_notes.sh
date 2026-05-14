#!/bin/bash

# ==========================================
# CLEAR RELEASE NOTES SCRIPT
# ==========================================
# This script clears version-specific changes from CHANGES_IN_VERSION.md
# It removes everything before "### Default Release Notes" and keeps the default template
#
# Usage:
#   ./scripts/workflows/clear_release_notes.sh

set -e

FILE_PATH="CHANGES_IN_VERSION.md"

echo "🧹 Clearing version-specific changes from $FILE_PATH..."

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "❌ Error: $FILE_PATH not found!"
    exit 1
fi

# Create a temporary file
TEMP_FILE=$(mktemp)

# Find the line with "### Default Release Notes" and keep everything from there
awk '/^### Default Release Notes/{found=1} found' "$FILE_PATH" > "$TEMP_FILE"

# Check if we found the default release notes section
if [ ! -s "$TEMP_FILE" ]; then
    echo "❌ Error: Could not find '### Default Release Notes' section in $FILE_PATH"
    rm "$TEMP_FILE"
    exit 1
fi

# Replace the original file with the cleaned version
mv "$TEMP_FILE" "$FILE_PATH"

echo "✅ Cleared version-specific changes from $FILE_PATH"
echo "📝 File now contains only the default release notes template"