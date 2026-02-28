#!/bin/bash

# Run MFA if AWS_MFA_DEVICE is set
if [[ -n "$AWS_MFA_DEVICE" ]]; then
  echo "Setting up AWS MFA..."
  /apps/tool_aws/aws_mfa.sh || true
else
  echo "AWS_MFA_DEVICE not set, skipping MFA setup"
fi

# Keep container running
tail -f /dev/null
