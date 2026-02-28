#!/bin/bash

# reset
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# assume role with 12 hour duration (43200 seconds) and MFA
# Use default-long-term profile to avoid role chaining limit (1 hour)
# MFA is required for assuming this role
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_ROLE_NAME}"
DURATION=${AWS_ROLE_DURATION:-43200}  # 12 hours default, can override with AWS_ROLE_DURATION env var

# Auto-generate MFA code if AWS_MFA_SECRET is set
if [[ -n "$AWS_MFA_SECRET" ]]; then
  MFA_CODE=$(python3 << 'PYTHON'
import pyotp
import os
secret = os.getenv('AWS_MFA_SECRET')
totp = pyotp.TOTP(secret)
print(totp.now())
PYTHON
)
  CREDENTIALS=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "eks-session" \
    --duration-seconds "$DURATION" \
    --profile default-long-term \
    --serial-number "$AWS_MFA_DEVICE" \
    --token-code "$MFA_CODE" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)

  # Check if credentials were obtained
  if [[ -z "$CREDENTIALS" ]]; then
    return 1
  fi
else
  echo "Error: AWS_MFA_SECRET not set. Cannot generate MFA code for assume-role."
  return 1
fi

# extract and export credentials
ACCESS_KEY=$(echo $CREDENTIALS | awk '{print $1}')
SECRET_KEY=$(echo $CREDENTIALS | awk '{print $2}')
SESSION_TOKEN=$(echo $CREDENTIALS | awk '{print $3}')

export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_SESSION_TOKEN=$SESSION_TOKEN

# Update ~/.bashrc with credentials (remove old entries first to avoid duplicates)
sed -i '/export AWS_ACCESS_KEY_ID=/d' ~/.bashrc
sed -i '/export AWS_SECRET_ACCESS_KEY=/d' ~/.bashrc
sed -i '/export AWS_SESSION_TOKEN=/d' ~/.bashrc
echo "export AWS_ACCESS_KEY_ID=$ACCESS_KEY" >> ~/.bashrc
echo "export AWS_SECRET_ACCESS_KEY=$SECRET_KEY" >> ~/.bashrc
echo "export AWS_SESSION_TOKEN=$SESSION_TOKEN" >> ~/.bashrc

echo "Role credentials saved to shell environment"
