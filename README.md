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
AWS_MFA_DEVICE=     # AWS MFA device

# ilmuchat Config
ILMUCHAT_DOMAIN=    # ilmuchat domain
ILMUCHAT_EMAIL=     # ilmuchat email/username
ILMUCHAT_PASSWORD=  # ilmuchat password

# RDS Development
RDS_DEV_HOST=                  # Development RDS endpoint
RDS_DEV_DATABASE=             # Development database name
RDS_DEV_ADMIN_USER=           # RDS admin username
RDS_DEV_ADMIN_PASSWORD=       # RDS admin password
RDS_DEV_MIGRATION_USER=       # RDS migration username
RDS_DEV_MIGRATION_PASSWORD=   # RDS migration password

# RDS Staging
RDS_STG_HOST=                 # Staging RDS endpoint
RDS_STG_DATABASE=            # Staging database name
RDS_STG_ADMIN_USER=          # RDS admin username
RDS_STG_ADMIN_PASSWORD=      # RDS admin password
RDS_STG_MIGRATION_USER=      # RDS migration username
RDS_STG_MIGRATION_PASSWORD=  # RDS migration password

# RDS Production
RDS_PROD_HOST=               # Production RDS endpoint
RDS_PROD_DATABASE=          # Production database name
RDS_PROD_ADMIN_USER=        # RDS admin username
RDS_PROD_ADMIN_PASSWORD=    # RDS admin password
RDS_PROD_MIGRATION_USER=    # RDS migration username
RDS_PROD_MIGRATION_PASSWORD= # RDS migration password
```