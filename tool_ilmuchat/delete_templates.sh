#!/bin/bash

# ilmuchat Template Deleter by Category
# Usage: ./delete_templates.sh [OPTIONS]
# Options:
#   --help              Show this help message
#   --category CATEGORY Category to delete (slides, poster, build, or all)
#                       Default: slides

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --help              Show this help message
  --category CATEGORY Category to delete: slides, poster, build, or all (delete all templates)
                      Default: slides

Examples:
  $(basename "$0")
  $(basename "$0") --category poster
  $(basename "$0") --category all
  $(basename "$0") --help
EOF
}

# Default values
CATEGORY="slides"

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
    *)
      echo "Error: Unknown option '$1'" >&2
      show_help >&2
      exit 1
      ;;
  esac
done

# Check if ILMUCHAT_DOMAIN is set
if [ -z "$ILMUCHAT_DOMAIN" ]; then
  echo "Error: ILMUCHAT_DOMAIN environment variable must be set" >&2
  exit 1
fi

TOKEN=$("$SCRIPT_DIR/get_token.sh")

if [ -z "$TOKEN" ]; then
  echo "Failed to get token"
  exit 1
fi

ENDPOINT="$ILMUCHAT_DOMAIN/api/v1/templates/"

echo "Deleting templates..."
echo "Category: $CATEGORY"
echo "---"

if [ "$CATEGORY" = "all" ]; then
  # Delete all templates
  curl -X DELETE "$ENDPOINT" \
    -H "Authorization: Bearer $TOKEN"
else
  # Delete specific category
  curl -X DELETE "$ENDPOINT?category=$CATEGORY" \
    -H "Authorization: Bearer $TOKEN"
fi

echo ""
echo "Done!"
