#!/bin/bash

# Sync environment variables from file to GitHub repository
# Creates new variables or updates existing ones
# Usage: ./sync_env_to_github.sh <repo> <env_file> [environment_name]

REPO="${1:-}"
ENV_FILE="${2:-}"
GH_ENV="${3:-}"

# Show usage
if [[ -z "$REPO" ]] || [[ -z "$ENV_FILE" ]]; then
  echo "Usage: $0 <owner/repo> <env_file> [environment_name]"
  echo ""
  echo "Examples:"
  echo "  $0 frogasia/agent-service /apps/temp/github/env/frogasia_agent-service_PROD_variables.txt PROD"
  exit 1
fi

# Verify file exists
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: File not found: $ENV_FILE"
  exit 1
fi

# Extract environment name from filename if not provided
if [[ -z "$GH_ENV" ]]; then
  if [[ $ENV_FILE =~ _([A-Z]+)_variables\.txt$ ]]; then
    GH_ENV="${BASH_REMATCH[1]}"
  else
    echo "Error: Could not extract environment name from filename"
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

# Verify gh CLI is authenticated
if ! gh auth status > /dev/null 2>&1; then
  echo "Error: Not authenticated with GitHub. Run: gh auth login"
  exit 1
fi

# Verify environment exists
if ! gh api repos/"$REPO"/environments/"$GH_ENV" > /dev/null 2>&1; then
  echo "Error: Environment '$GH_ENV' not found in repository"
  exit 1
fi

# Parse variables from file (skip headers and empty lines)
VARIABLES=$(tail -n +6 "$ENV_FILE" | grep '=' | grep -v '^$')

if [[ -z "$VARIABLES" ]]; then
  echo "No variables found in file"
  exit 1
fi

VAR_COUNT=$(echo "$VARIABLES" | wc -l)
echo "Found $VAR_COUNT variables to sync"
echo ""

# Get list of existing variables
echo "Fetching existing variables..."
EXISTING_VARS=$(gh api repos/"$REPO"/environments/"$GH_ENV"/variables --paginate -q '.variables[].name' 2>/dev/null | sort)

# Counter for created/updated
CREATED=0
UPDATED=0
FAILED=0
SKIPPED=0

echo "Syncing variables..."
echo ""

# Sync each variable
while IFS='=' read -r KEY VALUE; do
  [[ -z "$KEY" ]] && continue

  # Check if variable exists
  if echo "$EXISTING_VARS" | grep -q "^$KEY$"; then
    # Update existing variable
    if gh api repos/"$REPO"/environments/"$GH_ENV"/variables/"$KEY" -X PATCH -f value="$VALUE" > /dev/null 2>&1; then
      echo "✓ [UPDATE] $KEY"
      ((UPDATED++))
    else
      echo "✗ [FAILED] $KEY"
      ((FAILED++))
    fi
  else
    # Create new variable
    if gh api repos/"$REPO"/environments/"$GH_ENV"/variables -X POST -f name="$KEY" -f value="$VALUE" > /dev/null 2>&1; then
      echo "✓ [CREATE] $KEY"
      ((CREATED++))
    else
      echo "✗ [FAILED] $KEY"
      ((FAILED++))
    fi
  fi
done <<< "$VARIABLES"

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Created:  $CREATED"
echo "Updated:  $UPDATED"
echo "Failed:   $FAILED"
echo "Total:    $(($CREATED + $UPDATED + $FAILED))"
echo ""

if [[ $FAILED -gt 0 ]]; then
  echo "⚠️  Some variables failed to sync"
  exit 1
else
  echo "✓ All variables synced successfully!"
fi
