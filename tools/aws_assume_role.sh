#!/bin/bash

# reset
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# assume role
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_ROLE_NAME}"
CREDENTIALS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "eks-session" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

# export credentials
export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | awk '{print $1}')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | awk '{print $2}')
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | awk '{print $3}')
