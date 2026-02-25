#!/bin/bash

# ilmuchat Suggestions Deleter
# Usage: ./delete_suggestions.sh [OPTIONS]
# Options:
#   --help              Show this help message
#   --mode MODE         Mode for suggestions (chat, etc.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --help              Show this help message
  --mode MODE         Mode for suggestions to delete (default: chat)

Examples:
  $(basename "$0") --mode chat
  $(basename "$0") --mode build
  $(basename "$0") --help
EOF
}

# Default values
MODE="chat"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      show_help
      exit 0
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [ -z "$ILMUCHAT_DOMAIN" ]; then
  echo "Error: ILMUCHAT_DOMAIN environment variable must be set" >&2
  exit 1
fi

TOKEN=$("$SCRIPT_DIR/get_token.sh")

if [ -z "$TOKEN" ]; then
  echo "Failed to get token"
  exit 1
fi

ENDPOINT="$ILMUCHAT_DOMAIN/api/v1/suggestions"

echo "🗑️  Deleting suggestions..."
echo "Mode: $MODE"
echo "---"

RESPONSE=$(curl -s -X DELETE "$ENDPOINT/?mode=$MODE" \
  -H "Authorization: Bearer $TOKEN")

echo "Response: $RESPONSE"

# Check response
SUCCESS=$(echo "$RESPONSE" | jq -r '.success // false' 2>/dev/null)
if [ "$SUCCESS" = "true" ]; then
  echo "✅ Deleted successfully!"
  echo "$RESPONSE" | jq .
else
  DETAIL=$(echo "$RESPONSE" | jq -r '.detail // ""' 2>/dev/null)
  if [ -n "$DETAIL" ]; then
    echo "❌ Error: $DETAIL"
  else
    echo "❌ Failed to delete"
    echo "$RESPONSE" | jq .
  fi
  exit 1
fi
