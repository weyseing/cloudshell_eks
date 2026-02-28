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

# RDS Database Configuration
RDS_DEV_HOST=       # Dev RDS connection
RDS_DEV_DB=
RDS_DEV_USER=
RDS_DEV_PASS=

RDS_STG_HOST=       # Staging RDS connection
RDS_STG_DB=
RDS_STG_USER=
RDS_STG_PASS=

RDS_PROD_HOST=      # Production RDS connection
RDS_PROD_DB=
RDS_PROD_USER=
RDS_PROD_PASS=
```