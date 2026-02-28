#!/bin/bash
set -e

source "$(dirname "$0")/github_utils.sh"

# Sync environment variables from file to GitHub repository
# Creates new variables or updates existing ones

REPO=""
ENV_FILE=""
GH_ENV=""

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Sync environment variables from file to GitHub repository.

OPTIONS:
  --repo OWNER/REPO      GitHub repository (required)
  --file PATH            Variables file (required)
  --env NAME             Environment name (default: extracted from filename)
  --help                 Show this help message

EXAMPLES:
  $0 --repo frogasia/agent-service --file /apps/temp/github/env/frogasia_agent-service_PROD_variables.txt
  $0 --repo frogasia/agent-service --file vars.txt --env PROD

File format: KEY=VALUE pairs (headers and empty lines skipped)
EOF
  exit "${1:-0}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --file)
      ENV_FILE="$2"
      shift 2
      ;;
    --env)
      GH_ENV="$2"
      shift 2
      ;;
    --help)
      usage 0
      ;;
    *)
      echo "Error: Unknown option: $1"
      usage 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$REPO" ]] || [[ -z "$ENV_FILE" ]]; then
  echo "Error: --repo and --file are required"
  usage 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: File not found: $ENV_FILE"
  exit 1
fi

# Extract environment name from filename if not provided
if [[ -z "$GH_ENV" ]]; then
  if [[ $ENV_FILE =~ _([A-Z]+)_variables\.txt$ ]]; then
    GH_ENV="${BASH_REMATCH[1]}"
  else
    echo "Error: Could not extract environment name from filename. Provide with: --env NAME"
    exit 1
  fi
fi

echo "=========================================="
echo "GitHub Environment Variables Sync"
echo "=========================================="
echo "Repository: $REPO"
echo "Environment: $GH_ENV"
echo "Variables file: $ENV_FILE"
echo ""

# Verify GitHub authentication
check_github_auth

# Parse variables from file (skip header lines and empty lines)
VARIABLES=$(grep '=' "$ENV_FILE" | grep -v '^$' | head -n +99999)

if [[ -z "$VARIABLES" ]]; then
  echo "No variables found in file"
  exit 1
fi

VAR_COUNT=$(echo "$VARIABLES" | wc -l)
echo "Found $VAR_COUNT variables to sync"
echo ""

# Get list of existing variables with values and build associative array for O(1) lookup
echo "Fetching existing variables..."
declare -A EXISTING_VARS_MAP
while IFS='=' read -r VAR_NAME VAR_VALUE; do
  EXISTING_VARS_MAP["$VAR_NAME"]="$VAR_VALUE"
done < <(gh api repos/"$REPO"/environments/"$GH_ENV"/variables --paginate -q '.variables[] | "\(.name)=\(.value)"' 2>/dev/null)

# Counter for created/updated/skipped
CREATED=0
UPDATED=0
SKIPPED=0
FAILED=0

echo "Syncing variables..."
echo ""

# Sync each variable using associative array for O(1) lookup
while IFS='=' read -r KEY VALUE; do
  [[ -z "$KEY" ]] && continue

  if [[ -v EXISTING_VARS_MAP["$KEY"] ]]; then
    # Check if value is the same
    if [[ "${EXISTING_VARS_MAP[$KEY]}" == "$VALUE" ]]; then
      echo "⊘ [SKIP] $KEY"
      ((SKIPPED++)) || true
    else
      # Update existing variable with different value
      if gh api repos/"$REPO"/environments/"$GH_ENV"/variables/"$KEY" -X PATCH -f value="$VALUE" > /dev/null 2>&1; then
        echo "✓ [UPDATE] $KEY"
        ((UPDATED++)) || true
      else
        echo "✗ [FAILED] $KEY"
        ((FAILED++)) || true
      fi
    fi
  else
    # Create new variable
    if gh api repos/"$REPO"/environments/"$GH_ENV"/variables -X POST -f name="$KEY" -f value="$VALUE" > /dev/null 2>&1; then
      echo "✓ [CREATE] $KEY"
      ((CREATED++)) || true
    else
      echo "✗ [FAILED] $KEY"
      ((FAILED++)) || true
    fi
  fi
done <<< "$VARIABLES"

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Created:  $CREATED"
echo "Updated:  $UPDATED"
echo "Skipped:  $SKIPPED"
echo "Failed:   $FAILED"
echo "Total:    $(($CREATED + $UPDATED + $SKIPPED + $FAILED))"
echo ""

if [[ $FAILED -gt 0 ]]; then
  echo "⚠️  Some variables failed to sync"
  exit 1
else
  echo "✓ All variables synced successfully!"
fi
