#!/bin/bash

# ilmuchat BE Token Getter
# Usage: ./get_token.sh
# Required environment variables: ILMUCHAT_EMAIL, ILMUCHAT_PASSWORD

if [ -z "$ILMUCHAT_EMAIL" ] || [ -z "$ILMUCHAT_PASSWORD" ]; then
  echo "Error: ILMUCHAT_EMAIL and ILMUCHAT_PASSWORD environment variables must be set" >&2
  exit 1
fi

if [ -z "$ILMUCHAT_DOMAIN" ]; then
  echo "Error: ILMUCHAT_DOMAIN environment variable must be set" >&2
  exit 1
fi

ILMUCHAT_ENDPOINT="$ILMUCHAT_DOMAIN/api/v1/auths/signin"

curl -s -X POST "$ILMUCHAT_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$ILMUCHAT_EMAIL\",
    \"password\": \"$ILMUCHAT_PASSWORD\"
  }" | jq '.token' -r
