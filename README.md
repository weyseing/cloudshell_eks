# Setup Guide

- **Create `~/.aws/credentails`**
```properties
[default-long-term]
aws_access_key_id = ********
aws_secret_access_key = ********
```

- **Copy `.env.example` to `.env` & fill up values below**
```shell
# AWS Config
AWS_ACCOUNT_ID=     # AWS acc ID
AWS_ROLE_NAME=      # AWS IAM role
AWS_MFA_DEVICE=     # AWS MFA device

# GitHub Config
GH_TOKEN=           # GitHub personal access token (repo scope)
                    # Create at: GitHub → Settings → Developer settings → Personal access tokens
```