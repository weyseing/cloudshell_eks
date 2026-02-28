#!/bin/bash
set -e

source "$(dirname "$0")/github_utils.sh"

# Sync secrets from file to GitHub repository environment
# Creates new secrets or updates existing ones

REPO=""
SECRETS_FILE=""
GH_ENV=""

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Sync secrets from file to GitHub repository environment.

OPTIONS:
  --repo OWNER/REPO      GitHub repository (required)
  --file PATH            Secrets file (required)
  --env NAME             Environment name (default: extracted from filename)
  --help                 Show this help message

EXAMPLES:
  $0 --repo frogasia/agent-service --file /apps/cloudshell/temp/github/env/frogasia_agent-service_PROD_secrets.txt
  $0 --repo frogasia/agent-service --file secrets.txt --env PROD

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
      SECRETS_FILE="$2"
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
if [[ -z "$REPO" ]] || [[ -z "$SECRETS_FILE" ]]; then
  echo "Error: --repo and --file are required"
  usage 1
fi

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: File not found: $SECRETS_FILE"
  exit 1
fi

# Extract environment name from filename if not provided
if [[ -z "$GH_ENV" ]]; then
  if [[ $SECRETS_FILE =~ _([A-Z]+)_secrets\.txt$ ]]; then
    GH_ENV="${BASH_REMATCH[1]}"
  else
    echo "Error: Could not extract environment name from filename. Provide with: --env NAME"
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

# Verify GitHub authentication
check_github_auth

# Parse secrets from file (skip header lines and empty lines)
SECRETS=$(grep '=' "$SECRETS_FILE" | grep -v '^$' | head -n +99999)

if [[ -z "$SECRETS" ]]; then
  echo "No secrets found in file"
  exit 1
fi

SECRET_COUNT=$(echo "$SECRETS" | wc -l)
echo "Found $SECRET_COUNT secrets to sync"
echo ""

# Get list of existing secrets and build associative array for O(1) lookup
echo "Fetching existing secrets..."
declare -A EXISTING_SECRETS_MAP
while IFS= read -r SECRET_NAME; do
  EXISTING_SECRETS_MAP["$SECRET_NAME"]=1
done < <(gh api repos/"$REPO"/environments/"$GH_ENV"/secrets --paginate -q '.secrets[].name' 2>/dev/null)

# Counter for created/updated/skipped
CREATED=0
UPDATED=0
SKIPPED=0
FAILED=0

echo "Syncing secrets..."
echo ""

# Sync each secret using associative array for O(1) lookup
while IFS='=' read -r KEY VALUE; do
  [[ -z "$KEY" ]] && continue

  if [[ -v EXISTING_SECRETS_MAP["$KEY"] ]]; then
    ACTION="UPDATE"
  else
    ACTION="CREATE"
  fi

  # Use gh secret set with --body and --env flags
  if gh secret set "$KEY" --repo "$REPO" --env "$GH_ENV" --body "$VALUE" >/dev/null 2>&1; then
    echo "✓ [$ACTION] $KEY"
    if [[ "$ACTION" == "CREATE" ]]; then
      ((CREATED++)) || true
    else
      ((UPDATED++)) || true
    fi
  else
    echo "✗ [FAILED] $KEY"
    ((FAILED++)) || true
  fi
done <<< "$SECRETS"

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
  echo "⚠️  Some secrets failed to sync"
  exit 1
else
  echo "✓ All secrets synced successfully!"
  exit 0
fi
