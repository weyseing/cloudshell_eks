#!/bin/bash

# ilmuchat Suggestions Populator from CSV/XLSX
# Usage: ./populate_suggestions.sh [OPTIONS]
# Options:
#   --help              Show this help message
#   --mode MODE         Mode for suggestions (chat, etc.)
#   --file FILE_PATH    Path to CSV/XLSX file
#   --sheet-name SHEET  Excel sheet name (xlsx only)
#   --language LANG     Language code (en, bm, etc.) - Default: en
#   --delete            Delete existing suggestions in the same mode before populating

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --help              Show this help message
  --mode MODE         Mode for suggestions: chat (default)
  --file FILE_PATH    Path to CSV/XLSX file to populate suggestions from
  --sheet-name SHEET  Excel sheet name to use (xlsx only)
  --language LANG     Language code (en, bm, etc.)
                      Default: en
  --delete            Delete existing suggestions in the same mode before populating

CSV Format:
  SUGGESTION (EN),SUGGESTION (BM)
  Tell me a joke,Ceritakan aku lawak

Examples:
  $(basename "$0") --file suggestions.csv
  $(basename "$0") --language bm --mode chat --file suggestions.csv
  $(basename "$0") --language en --delete --file suggestions.csv
  $(basename "$0") --help
EOF
}

# Default values
MODE="chat"
FILE_PATH=""
SHEET_NAME=""
LANGUAGE="en"
DELETE_FIRST=false

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
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --sheet-name)
      SHEET_NAME="$2"
      shift 2
      ;;
    --language)
      LANGUAGE="$2"
      shift 2
      ;;
    --delete)
      DELETE_FIRST=true
      shift
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      show_help >&2
      exit 1
      ;;
  esac
done

# Check if file path is provided
if [ -z "$FILE_PATH" ]; then
  echo "Error: --file is required" >&2
  show_help >&2
  exit 1
fi
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

# URL encode function for query parameters
urlencode() {
  local string="${1}"
  echo -n "$string" | jq -sRr @uri
}

# Delete suggestions first if requested
if [ "$DELETE_FIRST" = true ]; then
  echo "🗑️  Deleting existing suggestions in mode: $MODE"
  DELETE_RESPONSE=$(curl -s -X DELETE "$ENDPOINT/?mode=$MODE" \
    -H "Authorization: Bearer $TOKEN")

  DELETE_SUCCESS=$(echo "$DELETE_RESPONSE" | jq -r '.success // false' 2>/dev/null)
  if [ "$DELETE_SUCCESS" = "true" ]; then
    echo "✅ Deleted successfully!"
  else
    echo "⚠️  Delete returned: $DELETE_RESPONSE"
  fi
  echo ""
fi

echo "📤 Populating suggestions..."
echo "Mode: $MODE"
echo "Language: $LANGUAGE"
echo "File: $FILE_PATH"
[ -n "$SHEET_NAME" ] && echo "Sheet: $SHEET_NAME"
echo "---"

# Step 1: Submit the file
QUERY_URL="$ENDPOINT/populate-from-csv?mode=$MODE&language=$LANGUAGE"
if [ -n "$SHEET_NAME" ]; then
  SHEET_ENCODED=$(urlencode "$SHEET_NAME")
  QUERY_URL="$QUERY_URL&sheet_name=$SHEET_ENCODED"
fi

RESPONSE=$(curl -s -X POST "$QUERY_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@$FILE_PATH")

echo "Response: $RESPONSE"

# Check if this is a direct response (with total_rows) or async job response
TOTAL_ROWS=$(echo "$RESPONSE" | jq -r '.total_rows // ""' 2>/dev/null)
JOB_ID=$(echo "$RESPONSE" | jq -r '.job_id // ""' 2>/dev/null)

# Handle direct response (suggestions endpoint)
if [ -n "$TOTAL_ROWS" ]; then
  SUCCEEDED=$(echo "$RESPONSE" | jq -r '.succeeded' 2>/dev/null)
  PROCESSED=$(echo "$RESPONSE" | jq -r '.processed' 2>/dev/null)

  if [ "$SUCCEEDED" = "$PROCESSED" ]; then
    echo -e "\n✅ All suggestions populated successfully!"
    echo "Total rows: $TOTAL_ROWS"
    echo "Processed: $PROCESSED"
    echo "Succeeded: $SUCCEEDED"
  else
    echo -e "\n⚠️  Some suggestions failed!"
    echo "Total rows: $TOTAL_ROWS"
    echo "Processed: $PROCESSED"
    echo "Succeeded: $SUCCEEDED"
    echo "$RESPONSE" | jq .
  fi
  exit 0
fi