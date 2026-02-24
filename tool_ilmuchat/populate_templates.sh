#!/bin/bash

# ilmuchat Template Populator from CSV/XLSX
# Usage: ./populate_templates.sh [OPTIONS]
# Options:
#   --help              Show this help message
#   --category CATEGORY Category for templates (slides, poster, build, auto)
#   --file FILE_PATH    Path to CSV/XLSX file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --help              Show this help message
  --category CATEGORY Category for templates: slides, poster, build, or auto for auto-detection
                      Default: slides
  --file FILE_PATH    Path to CSV/XLSX file to populate templates from
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

# Delete templates first if requested
if [ "$DELETE_FIRST" = true ]; then
  echo "Deleting existing templates in category: $CATEGORY"
  "$SCRIPT_DIR/delete_templates.sh" --category "$CATEGORY"
  echo ""
fi

echo "Populating templates..."
echo "Category: $CATEGORY"
echo "File: $FILE_PATH"
echo "---"

if [ "$CATEGORY" = "auto" ]; then
  # Auto-detection from chat session data
  curl -X POST "$ENDPOINT?is_published=true" \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@\"$FILE_PATH\""
else
  # Specific category
  curl -X POST "$ENDPOINT?category=$CATEGORY&is_published=true" \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@\"$FILE_PATH\""
fi

echo ""
echo "Done!"
