#!/bin/bash
# github_utils.sh - Shared GitHub CLI utilities

check_github_auth() {
  if ! gh auth status &>/dev/null; then
    echo "Error: GitHub authentication failed"
    echo "Please run: gh auth login --with-token"
    exit 1
  fi
}
