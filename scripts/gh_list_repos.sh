#!/bin/bash
set -e

ENV_FILE="$(dirname "$0")/../temp/.env"

# ─── AUTH ─────────────────────────────────────────────────────────────────────
# Load from env file if exists
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

# Prompt if still not set
if [ -z "$GH_TOKEN" ]; then
  read -rsp "Enter GitHub Token: " GH_TOKEN
  echo

  # Save token to env file (hidden from script output)
  mkdir -p "$(dirname "$ENV_FILE")"
  grep -v "^GH_TOKEN=" "$ENV_FILE" 2>/dev/null > "${ENV_FILE}.tmp" || true
  echo "GH_TOKEN=$GH_TOKEN" >> "${ENV_FILE}.tmp"
  mv "${ENV_FILE}.tmp" "$ENV_FILE"
  echo "GH_TOKEN saved to $ENV_FILE"
fi

# ─── LIST REPOS ───────────────────────────────────────────────────────────────
GH_USER="${1:-}"

if [ -z "$GH_USER" ]; then
  # List repos for the authenticated user
  curl -s -H "Authorization: Bearer $GH_TOKEN" \
    "https://api.github.com/user/repos?per_page=100&sort=updated" \
    | grep '"full_name"' | awk -F'"' '{print $4}'
else
  # List repos for a specific org or user
  curl -s -H "Authorization: Bearer $GH_TOKEN" \
    "https://api.github.com/users/$GH_USER/repos?per_page=100&sort=updated" \
    | grep '"full_name"' | awk -F'"' '{print $4}'
fi
