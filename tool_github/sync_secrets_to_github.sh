#!/bin/bash

# Sync secrets from file to GitHub repository environment
# Creates new secrets or updates existing ones
# Usage: ./sync_secrets_to_github.sh <repo> <secrets_file> [environment_name]

REPO="${1:-}"
SECRETS_FILE="${2:-}"
GH_ENV="${3:-}"

# Show usage
if [[ -z "$REPO" ]] || [[ -z "$SECRETS_FILE" ]]; then
  echo "Usage: $0 <owner/repo> <secrets_file> [environment_name]"
  echo ""
  echo "Examples:"
  echo "  $0 frogasia/agent-service /apps/temp/github/env/frogasia_agent-service_PROD_secrets.txt PROD"
  exit 1
fi

# Verify file exists
if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: File not found: $SECRETS_FILE"
  exit 1
fi

# Extract environment name from filename if not provided
if [[ -z "$GH_ENV" ]]; then
  if [[ $SECRETS_FILE =~ _([A-Z]+)_secrets\.txt$ ]]; then
    GH_ENV="${BASH_REMATCH[1]}"
  else
    echo "Error: Could not extract environment name from filename"
    exit 1
  fi
fi

echo "=========================================="
echo "GitHub Environment Secrets Sync"
echo "=========================================="
echo "Repository: $REPO"
echo "Environment: $GH_ENV"
echo "Secrets file: $SECRETS_FILE"
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

# Parse secrets from file (skip headers and empty lines)
SECRETS=$(tail -n +6 "$SECRETS_FILE" | grep '=' | grep -v '^$')

if [[ -z "$SECRETS" ]]; then
  echo "No secrets found in file"
  exit 1
fi

SECRET_COUNT=$(echo "$SECRETS" | wc -l)
echo "Found $SECRET_COUNT secrets to sync"
echo ""

# Get list of existing secrets
echo "Fetching existing secrets..."
EXISTING_SECRETS=$(gh api repos/"$REPO"/environments/"$GH_ENV"/secrets --paginate -q '.secrets[].name' 2>/dev/null | sort)

# Counter for created/updated
CREATED=0
UPDATED=0
FAILED=0

echo "Syncing secrets..."
echo ""

# Sync each secret using gh secret set with --body and --env flags
while IFS='=' read -r KEY VALUE; do
  # Skip empty keys
  if [[ -z "$KEY" ]]; then
    continue
  fi

  # Check if secret exists
  if echo "$EXISTING_SECRETS" | grep -q "^$KEY$"; then
    ACTION="UPDATE"
  else
    ACTION="CREATE"
  fi

  # Use gh secret set with --body and --env flags
  if gh secret set "$KEY" --repo "$REPO" --env "$GH_ENV" --body "$VALUE" >/dev/null 2>&1; then
    echo "✓ [$ACTION] $KEY"
    if [[ "$ACTION" == "CREATE" ]]; then
      ((CREATED++))
    else
      ((UPDATED++))
    fi
  else
    echo "✗ [FAILED] $KEY"
    ((FAILED++))
  fi
done <<< "$SECRETS"

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
  echo "⚠️  Some secrets failed to sync"
  exit 1
else
  echo "✓ All secrets synced successfully!"
  exit 0
fi
