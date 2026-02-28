#!/bin/bash
set -e

source "$(dirname "$0")/github_utils.sh"

# Export GitHub repository secrets and environment variables to separate files
# Splits by: environment + type (secrets/variables)

REPO=""
OUTPUT_DIR="/apps/temp/github/env"

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Export GitHub repository secrets and environment variables to separate files.

OPTIONS:
  --repo OWNER/REPO      GitHub repository (required)
  --output DIR           Output directory (default: /apps/temp/github/env)
  --help                 Show this help message

EXAMPLES:
  $0 --repo frogasia/agent-service
  $0 --repo frogasia/agent-service --output /tmp/github

If --repo is not provided, attempts to extract from git remote origin.
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
    --output)
      OUTPUT_DIR="$2"
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

# Extract from git remote if not provided
if [[ -z "$REPO" ]]; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ $REMOTE_URL =~ github.com[:/]([^/]+)/([^/]+)\.git$ ]]; then
    REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    echo "Error: Could not extract repo from git remote. Provide with: --repo owner/repo"
    usage 1
  fi
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

REPO_NAME=$(echo "$REPO" | tr '/' '_')

# Verify GitHub authentication
check_github_auth

echo "Exporting environment from: $REPO"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Export repository-level secrets and variables
echo "Exporting repository-level configuration..."

# Repository level Secrets (no header in output, get first column only)
SECRETS=$(gh secret list --repo "$REPO" 2>/dev/null | awk '{print $1}' || echo "")
if [[ -n "$SECRETS" ]]; then
  FILENAME="${OUTPUT_DIR}/${REPO_NAME}_repo_secrets.txt"
  {
    echo "GitHub Repository Secrets"
    echo "Repository: $REPO"
    echo "Exported: $(date)"
    echo ""
    echo "$SECRETS" | awk '{print $0 "=***"}'
  } > "$FILENAME"
  echo "✓ $FILENAME"
fi

# Repository level Variables (use paginated API to avoid N+1 queries)
VARIABLES=$(gh api repos/"$REPO"/actions/variables --paginate -q '.variables[] | "\(.name)=\(.value)"' 2>/dev/null || echo "")
if [[ -n "$VARIABLES" ]]; then
  FILENAME="${OUTPUT_DIR}/${REPO_NAME}_repo_variables.txt"
  {
    echo "GitHub Repository Variables"
    echo "Repository: $REPO"
    echo "Exported: $(date)"
    echo ""
    echo "$VARIABLES"
  } > "$FILENAME"
  echo "✓ $FILENAME"
fi

echo ""
echo "Exporting environment-specific configuration..."

# Environment-specific secrets and variables
ENVS=$(gh api repos/"$REPO"/environments --paginate -q '.environments[].name' 2>/dev/null || echo "")

if [[ -z "$ENVS" ]]; then
  echo "No environments found"
else
  while IFS= read -r ENV; do
    if [[ -n "$ENV" ]]; then
      # Export secrets for this environment (no header in output, get first column only)
      SECRETS=$(gh secret list --repo "$REPO" --env "$ENV" 2>/dev/null | awk '{print $1}' || echo "")
      if [[ -n "$SECRETS" ]]; then
        FILENAME="${OUTPUT_DIR}/${REPO_NAME}_${ENV}_secrets.txt"
        {
          echo "GitHub Environment Secrets"
          echo "Repository: $REPO"
          echo "Environment: $ENV"
          echo "Exported: $(date)"
          echo ""
          echo "$SECRETS" | awk '{print $0 "=***"}'
        } > "$FILENAME"
        echo "✓ $FILENAME"
      fi

      # Export variables for this environment
      VARS=$(gh api repos/"$REPO"/environments/"$ENV"/variables --paginate -q '.variables[] | "\(.name)=\(.value)"' 2>/dev/null || echo "")
      if [[ -n "$VARS" ]]; then
        FILENAME="${OUTPUT_DIR}/${REPO_NAME}_${ENV}_variables.txt"
        {
          echo "GitHub Environment Variables"
          echo "Repository: $REPO"
          echo "Environment: $ENV"
          echo "Exported: $(date)"
          echo ""
          echo "$VARS"
        } > "$FILENAME"
        echo "✓ $FILENAME"
      fi
    fi
  done <<< "$ENVS"
fi

echo ""
echo "=== Export Summary ==="
echo "All files exported to: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/${REPO_NAME}*.txt 2>/dev/null || echo "No files created"
