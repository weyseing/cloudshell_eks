#!/bin/bash
set -e

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0"; exit 0 ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# If AWS_MFA_SECRET is set, auto-generate MFA code using pyotp
if [[ -n "$AWS_MFA_SECRET" ]]; then
  echo "Auto-generating MFA code..."
  CODE=$(python3 << 'PYTHON'
import pyotp
import os
secret = os.getenv('AWS_MFA_SECRET')
totp = pyotp.TOTP(secret)
print(totp.now())
PYTHON
)
  echo "Generated MFA code: $CODE"

  # Get session token and parse credentials
  RESPONSE=$(aws sts get-session-token --serial-number "$AWS_MFA_DEVICE" --token-code "$CODE" --profile default-long-term)

  # Parse credentials from JSON response
  ACCESS_KEY=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])")
  SECRET_KEY=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])")
  SESSION_TOKEN=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['SessionToken'])")

  # Create ~/.aws/credentials if it doesn't exist
  mkdir -p ~/.aws

  # Update default profile with session credentials
  python3 << PYTHON
import configparser
import os

credentials_file = os.path.expanduser('~/.aws/credentials')
config = configparser.ConfigParser()
config.read(credentials_file)

if 'default' not in config:
    config['default'] = {}

config['default']['aws_access_key_id'] = '$ACCESS_KEY'
config['default']['aws_secret_access_key'] = '$SECRET_KEY'
config['default']['aws_session_token'] = '$SESSION_TOKEN'

with open(credentials_file, 'w') as f:
    config.write(f)
PYTHON

  echo "MFA authentication successful! Credentials saved to ~/.aws/credentials"
else
  # Fallback to aws-mfa tool for manual entry
  aws-mfa --device "$AWS_MFA_DEVICE" --profile default
fi
