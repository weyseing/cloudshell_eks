#!/bin/bash

# AWS MFA with retry logic
MFA_SUCCESS=0
if [[ -n "$AWS_MFA_DEVICE" && -n "$AWS_MFA_SECRET" ]]; then
  echo "Setting up AWS MFA..."
  for i in {1..3}; do
    if /apps/tool_aws/aws_mfa.sh; then
      MFA_SUCCESS=1
      echo "AWS MFA setup successful"
      break
    fi
    if [ $i -lt 3 ]; then
      echo "Retry attempt $((i+1))/3 in 31 seconds..."
      sleep 31
    fi
  done
  if [ $MFA_SUCCESS -eq 0 ]; then
    echo "AWS MFA setup failed after 3 attempts"
  fi
else
  echo "AWS_MFA_DEVICE or AWS_MFA_SECRET not set, skipping MFA setup"
fi

# AWS assume role
if [[ $MFA_SUCCESS -eq 1 && -n "$AWS_ACCOUNT_ID" && -n "$AWS_ROLE_NAME" && -n "$AWS_MFA_SECRET" ]]; then
  echo "Assuming IAM role with MFA..."
  for i in {1..3}; do
    source /apps/tool_aws/aws_assume_role.sh && break
    if [ $i -lt 3 ]; then
      echo "Retry attempt $((i+1))/3 in 31 seconds (waiting for next TOTP code)..."
      sleep 31
    fi
  done
else
  echo "Skipping role assumption (MFA setup not successful or required vars not set)"
fi

# Keep container running
tail -f /dev/null
