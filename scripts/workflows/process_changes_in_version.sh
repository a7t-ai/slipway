#!/bin/bash

# ==========================================
# PROCESS CHANGES_IN_VERSION.MD SCRIPT
# ==========================================
# This script reads CHANGES_IN_VERSION.md and extracts custom changes
# or selects a random default release note
#
# Usage: ./scripts/process_changes_in_version.sh
#
# Outputs (via GitHub Actions outputs):
# - has_custom_changes: true/false
# - custom_changes: semicolon-separated custom changes (if any)
# - selected_default: randomly selected default note (if no custom changes)

set -e

echo "📋 Reading CHANGES_IN_VERSION.md..."

# Check if file exists
if [ ! -f "CHANGES_IN_VERSION.md" ]; then
    echo "❌ CHANGES_IN_VERSION.md not found"
    exit 1
fi

# Extract content before "### Default Release Notes"
CUSTOM_CHANGES=$(awk '/### Default Release Notes/{exit} 1' CHANGES_IN_VERSION.md | sed '/^$/d' | grep -v '^#' || true)

# Extract default release notes (after the header, before any other ### section)
DEFAULT_NOTES=$(awk '/### Default Release Notes/{flag=1; next} /^###/{flag=0} flag' CHANGES_IN_VERSION.md | grep -v '^$' | grep '^-' || true)

echo "🔍 Custom changes found:"
echo "$CUSTOM_CHANGES"

# Check if there are custom changes (non-empty after filtering)
if [ -n "$CUSTOM_CHANGES" ] && [ "$(echo "$CUSTOM_CHANGES" | grep -c '^-')" -gt 0 ]; then
    echo "has_custom_changes=true" >> $GITHUB_OUTPUT
    # Remove leading dashes and clean up for AI processing
    CLEAN_CHANGES=$(echo "$CUSTOM_CHANGES" | sed 's/^- //' | tr '\n' ';' | sed 's/;$//')
    # Use heredoc format to safely output values with special characters
    {
        echo "custom_changes<<EOF"
        echo "$CLEAN_CHANGES"
        echo "EOF"
    } >> $GITHUB_OUTPUT
    echo "✅ Found custom changes: $CLEAN_CHANGES"
else
    echo "has_custom_changes=false" >> $GITHUB_OUTPUT
    # Select random default note
    DEFAULT_COUNT=$(echo "$DEFAULT_NOTES" | wc -l | xargs)
    RANDOM_LINE=$((RANDOM % DEFAULT_COUNT + 1))
    SELECTED_DEFAULT=$(echo "$DEFAULT_NOTES" | sed -n "${RANDOM_LINE}p" | sed 's/^- //')
    # Use heredoc format to safely output values with special characters
    {
        echo "selected_default<<EOF"
        echo "$SELECTED_DEFAULT"
        echo "EOF"
    } >> $GITHUB_OUTPUT
    echo "🎲 Selected random default: $SELECTED_DEFAULT"
fi

echo "✅ CHANGES_IN_VERSION.md processed successfully"