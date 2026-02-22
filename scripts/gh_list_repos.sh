#!/bin/bash
set -e

# ─── AUTH ─────────────────────────────────────────────────────────────────────
if [ -z "$GH_TOKEN" ]; then
  echo "Error: GH_TOKEN is not set. Add it to your .env file." >&2
  exit 1
fi

# ─── ARGS ─────────────────────────────────────────────────────────────────────
GH_USER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) GH_USER="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$GH_USER" ]; then
  echo "Error: --user is required. Usage: $0 --user <github-user-or-org>" >&2
  exit 1
fi

# ─── LIST REPOS ───────────────────────────────────────────────────────────────
gh repo list "$GH_USER" --limit 100
