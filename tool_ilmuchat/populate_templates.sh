#!/bin/bash

# ilmuchat Template Populator from CSV/XLSX
# Usage: ./populate_templates.sh [OPTIONS]
# Options:
#   --help              Show this help message
#   --category CATEGORY Category for templates (slides, poster, build, auto)
#   --file FILE_PATH    Path to CSV/XLSX file
#   --sheet-name SHEET  Excel sheet name (xlsx only)
#   --delete            Delete existing templates in the same category before populating

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --help              Show this help message
  --category CATEGORY Category for templates: slides, poster, build, or auto for auto-detection
                      Default: slides
  --file FILE_PATH    Path to CSV/XLSX file to populate templates from
  --sheet-name SHEET  Excel sheet name to use (xlsx only)
  --delete            Delete existing templates in the same category before populating

Examples:
  $(basename "$0") --file data.xlsx
  $(basename "$0") --category poster --file templates.csv
  $(basename "$0") --delete --file data.xlsx
  $(basename "$0") --help
EOF
}

# Default values
CATEGORY="slides"
FILE_PATH=""
SHEET_NAME=""
DELETE_FIRST=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      show_help
      exit 0
      ;;
    --category)
      CATEGORY="$2"
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

ENDPOINT="$ILMUCHAT_DOMAIN/api/v1/templates/populate-from-csv"

# URL encode function for query parameters
urlencode() {
  local string="${1}"
  echo -n "$string" | jq -sRr @uri
}

# Delete templates first if requested
if [ "$DELETE_FIRST" = true ]; then
  echo "Deleting existing templates in category: $CATEGORY"
  "$SCRIPT_DIR/delete_templates.sh" --category "$CATEGORY"
  echo ""
fi

echo "📤 Populating templates..."
echo "Category: $CATEGORY"
echo "File: $FILE_PATH"
[ -n "$SHEET_NAME" ] && echo "Sheet: $SHEET_NAME"
echo "---"

# Step 1: Submit the file
QUERY_URL="$ENDPOINT?category=$CATEGORY&is_published=true"
if [ -n "$SHEET_NAME" ]; then
  SHEET_ENCODED=$(urlencode "$SHEET_NAME")
  QUERY_URL="$QUERY_URL&sheet_name=$SHEET_ENCODED"
fi

RESPONSE=$(curl -s -X POST "$QUERY_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@$FILE_PATH")

echo "Response: $RESPONSE"

JOB_ID=$(echo "$RESPONSE" | jq -r '.job_id' 2>/dev/null)

if [ -z "$JOB_ID" ] || [ "$JOB_ID" = "null" ]; then
  echo "❌ Failed to get job_id from response"
  echo "Response: $RESPONSE"
  exit 1
fi

echo "Job ID: $JOB_ID"

# Step 2: Poll the status
echo -e "\n⏳ Waiting for job to complete..."
sleep 1  # Wait 1 second before first poll to ensure job is registered
MAX_ATTEMPTS=120  # 240 seconds max (4 minutes)
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  STATUS_RESPONSE=$(curl -s -X GET "$ENDPOINT/status/$JOB_ID" \
    -H "Authorization: Bearer $TOKEN")

  # Extract status, handle "Job not found" errors gracefully
  STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // ""' 2>/dev/null)
  ERROR=$(echo "$STATUS_RESPONSE" | jq -r '.detail // ""' 2>/dev/null)

  # Only display status if we have one (skip "Job not found" noise)
  if [ "$ERROR" = "Job not found" ]; then
    # Job not yet available on this instance, keep retrying silently
    true
  elif [ -n "$STATUS" ]; then
    echo "[$ATTEMPT/$MAX_ATTEMPTS] Status: $STATUS"
  fi

  if [ "$STATUS" = "done" ]; then
    echo -e "\n✅ Job completed successfully!"
    echo "$STATUS_RESPONSE" | jq .
    break
  elif [ "$STATUS" = "failed" ]; then
    echo -e "\n❌ Job failed!"
    echo "$STATUS_RESPONSE" | jq .
    exit 1
  fi

  ATTEMPT=$((ATTEMPT + 1))
  sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo -e "\n⚠️  Job timed out after ${MAX_ATTEMPTS} attempts"
  exit 1
fi
