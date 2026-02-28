#!/bin/bash
set -e

# Export GitHub repository secrets and environment variables to separate files
# Splits by: environment + type (secrets/variables)
# Usage: ./export_env_split.sh [owner/repo] [output_dir]

REPO="${1:-}"
OUTPUT_DIR="${2:-/apps/temp/github/env}"

# Extract from git remote if not provided
if [[ -z "$REPO" ]]; then
  REMOTE_URL=$(git remote get-url origin)
  if [[ $REMOTE_URL =~ github.com[:/]([^/]+)/([^/]+)\.git$ ]]; then
    REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    echo "Error: Could not extract repo from git remote. Provide as argument: owner/repo"
    exit 1
  fi
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

REPO_NAME=$(echo "$REPO" | tr '/' '_')

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

# Repository level Variables (no header in output, get first column only)
VARIABLES=$(gh variable list --repo "$REPO" 2>/dev/null | awk '{print $1}' || echo "")
if [[ -n "$VARIABLES" ]]; then
  FILENAME="${OUTPUT_DIR}/${REPO_NAME}_repo_variables.txt"
  {
    echo "GitHub Repository Variables"
    echo "Repository: $REPO"
    echo "Exported: $(date)"
    echo ""
    while IFS= read -r VAR; do
      if [[ -n "$VAR" ]]; then
        VALUE=$(gh api repos/"$REPO"/actions/variables/"$VAR" -q '.value' 2>/dev/null || echo "")
        echo "$VAR=$VALUE"
      fi
    done <<< "$VARIABLES"
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
