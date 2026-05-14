#!/bin/bash

# ==========================================
# GENERATE RELEASE NOTES SCRIPT (BASH VERSION)
# ==========================================
# This script generates AI-powered release notes using DeepSeek API
# and translates them to multiple languages using bash and curl
#
# Usage:
#   ./scripts/workflows/generate_release_notes.sh --type custom --changes "change1;change2"
#   ./scripts/workflows/generate_release_notes.sh --type default --note "default note"
#
# Environment Variables:
#   DEEPSEEK_API_KEY - Required for AI generation

set -e

# Default values
TYPE=""
CHANGES=""
NOTE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            TYPE="$2"
            shift 2
            ;;
        --changes)
            CHANGES="$2"
            shift 2
            ;;
        --note)
            NOTE="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$TYPE" ]; then
    echo "❌ Error: --type is required (custom or default)"
    exit 1
fi

if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "❌ Error: DEEPSEEK_API_KEY environment variable is required"
    exit 1
fi

# Load copywriting persona (voice, tone, anti-slop rules) to steer the model
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSONA_FILE="$SCRIPT_DIR/copywriting_persona.md"
if [ -f "$PERSONA_FILE" ]; then
    PERSONA_CONTENT=$(cat "$PERSONA_FILE")
else
    echo "⚠️  Warning: copywriting_persona.md not found at $PERSONA_FILE; falling back to default system prompt"
    PERSONA_CONTENT=""
fi

# JSON-escape stdin for safe embedding in a JSON payload
json_escape() {
    python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read()))'
}

# Function to call DeepSeek API
call_deepseek_api() {
    local prompt="$1"
    local max_tokens="${2:-150}"

    local system_message="You are a helpful assistant that creates App Store release notes for an iOS app. Be concise, engaging, and user-friendly. Focus on benefits to users."
    if [ -n "$PERSONA_CONTENT" ]; then
        system_message="${system_message}

Follow the voice, tone, and writing rules defined in the persona below. Pay special attention to the Anti-Slop Rules (banned phrases and patterns) and the rule against em dashes and en dashes.

--- PERSONA ---
${PERSONA_CONTENT}
--- END PERSONA ---"
    fi

    local escaped_system
    escaped_system=$(printf '%s' "$system_message" | json_escape)
    local escaped_user
    escaped_user=$(printf '%s' "$prompt" | json_escape)

    local json_payload=$(cat <<EOF
{
    "model": "deepseek-chat",
    "messages": [
        {
            "role": "system",
            "content": $escaped_system
        },
        {
            "role": "user",
            "content": $escaped_user
        }
    ],
    "max_tokens": $max_tokens,
    "temperature": 0.7
}
EOF
)
    
    # Make API call
    local response=$(curl -s -X POST "https://api.deepseek.com/chat/completions" \
        -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload")
    
    # Extract content from response
    local content=$(echo "$response" | grep -o '"content":"[^"]*"' | head -1 | sed 's/"content":"//' | sed 's/"$//' | sed 's/\\n/\n/g' | sed 's/\\"/"/g')
    
    if [ -z "$content" ]; then
        echo "❌ Error: Failed to get response from DeepSeek API"
        echo "Response: $response"
        exit 1
    fi
    
    echo "$content"
}

# Function to generate release notes based on type
generate_release_notes() {
    local prompt=""
    
    if [ "$TYPE" = "custom" ]; then
        if [ -z "$CHANGES" ]; then
            echo "❌ Error: --changes is required for custom type"
            exit 1
        fi
        
        # Convert semicolon-separated changes to bullet points
        local formatted_changes=$(echo "$CHANGES" | tr ';' '\n' | sed 's/^/- /')

        prompt="Create engaging App Store release notes as a cohesive paragraph for these app changes:

$formatted_changes

Important formatting rules:
- Write a cohesive paragraph with multiple sentences for better readability
- Use periods to create natural breaks between distinct features or ideas
- Do NOT use bullet points, dashes (—), em-dashes, en-dashes, hyphens, or emojis
- Connect related ideas with commas and conjunctions, but separate major features with periods
- Make it user-friendly, highlighting benefits and improvements
- Keep it concise, exciting, and engaging as a unified message

Critical content rule:
- Do NOT invent or add any features not listed above
- Only describe the changes explicitly provided in the list
- Stay strictly accurate to what was actually changed"
        
    elif [ "$TYPE" = "default" ]; then
        if [ -z "$NOTE" ]; then
            echo "❌ Error: --note is required for default type"
            exit 1
        fi

        prompt="Transform this default release note into an engaging App Store description paragraph:

\"$NOTE\"

Important formatting rules:
- Write a cohesive paragraph with multiple sentences for better readability
- Use periods to separate distinct ideas and create natural breaks
- Do NOT use bullet points, dashes (—), em-dashes, en-dashes, or hyphens for separation
- Connect related ideas with commas and conjunctions, but use periods between major points
- Keep the playful tone while being professional and user-focused
- Highlight the value to users in a flowing, conversational style

Critical content rule:
- Do NOT invent or add any specific features or changes
- Only expand and refine the general message provided above
- Keep the description general and avoid mentioning specific features not stated"
        
    else
        echo "❌ Error: Invalid type '$TYPE'. Must be 'custom' or 'default'"
        exit 1
    fi
    
    echo "🤖 Generating English release notes..." >&2
    call_deepseek_api "$prompt" 200
}

# Function to translate text
translate_text() {
    local text="$1"
    local target_language="$2"
    local language_name="$3"

    echo "🌍 Translating to $language_name..." >&2

    local prompt="Translate this App Store release note to $target_language:

\"$text\"

Translation guidelines:
- Convert idioms and expressions to their natural equivalents in the target language
- Do NOT use literal word-for-word translations
- Adapt cultural references to be appropriate for the target audience
- Ensure it sounds completely natural to native speakers
- Keep the same tone, style, and message intent
- Maintain the same formatting (single paragraph, no dashes)

Provide only the translation, no explanations."

    call_deepseek_api "$prompt" 250
}

# Generate English release notes
echo "📝 Generating AI-powered release notes..."
ENGLISH_NOTES=$(generate_release_notes)

if [ -z "$ENGLISH_NOTES" ]; then
    echo "❌ Failed to generate English release notes"
    exit 1
fi

echo "✅ Generated English release notes"

# Generate translations
GERMAN_NOTES=$(translate_text "$ENGLISH_NOTES" "German" "German")
PORTUGUESE_NOTES=$(translate_text "$ENGLISH_NOTES" "Portuguese (Brazil)" "Portuguese (Brazil)")
SPANISH_NOTES=$(translate_text "$ENGLISH_NOTES" "Spanish (Spain)" "Spanish (Spain)")

# Validate all translations were generated
if [ -z "$GERMAN_NOTES" ] || [ -z "$PORTUGUESE_NOTES" ] || [ -z "$SPANISH_NOTES" ]; then
    echo "❌ Failed to generate all translations"
    exit 1
fi

echo "✅ Generated all translations"

# Output to GitHub Actions using heredoc for multiline strings
{
    echo "english_notes<<EOF"
    echo "$ENGLISH_NOTES"
    echo "EOF"
} >> $GITHUB_OUTPUT

{
    echo "german_notes<<EOF"
    echo "$GERMAN_NOTES"
    echo "EOF"
} >> $GITHUB_OUTPUT

{
    echo "portuguese_notes<<EOF"
    echo "$PORTUGUESE_NOTES"
    echo "EOF"
} >> $GITHUB_OUTPUT

{
    echo "spanish_notes<<EOF"
    echo "$SPANISH_NOTES"
    echo "EOF"
} >> $GITHUB_OUTPUT

# Debug output
echo ""
echo "📋 Generated Release Notes:"
echo "🇺🇸 English: $ENGLISH_NOTES"
echo "🇩🇪 German: $GERMAN_NOTES"
echo "🇧🇷 Portuguese: $PORTUGUESE_NOTES"
echo "🇪🇸 Spanish: $SPANISH_NOTES"

echo ""
echo "✅ Release notes generation completed successfully"