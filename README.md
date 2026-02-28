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
AWS_ACCOUNT_ID=     # AWS account ID
AWS_ROLE_NAME=      # AWS IAM role
AWS_MFA_DEVICE=     # AWS MFA device ARN
AWS_MFA_SECRET=     # AWS MFA secret key

# ilmuchat Config
ILMUCHAT_DOMAIN=    # ilmuchat domain
ILMUCHAT_EMAIL=     # ilmuchat email/username
ILMUCHAT_PASSWORD=  # ilmuchat password

# GitHub Config
GITHUB_TOKEN=       # github token
```