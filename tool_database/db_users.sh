#!/bin/bash
# RDS List Users and Permissions Script

set -e

# Default values (RDS env vars from Docker container)
ENV=""
CUSTOM_DB=""

# Show help
show_help() {
    cat <<EOF
Usage: $0 --env <dev|stg|prod> [OPTIONS]

RDS List Users and Permissions Script - Display all users and their roles/permissions

Required Arguments:
  --env <dev|stg|prod>          Target RDS environment (dev, stg, or prod)

Optional Arguments:
  --db <database>               Specific database to check permissions
  --help                        Show this help message

Examples:
  # List all users in dev RDS
  $0 --env dev

  # List users and their database-specific permissions
  $0 --env dev --db agents_dev

  # List users in staging RDS
  $0 --env stg

Output:
  Displays all database users, roles, and their permissions
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV="$2"
            shift 2
            ;;
        --db)
            CUSTOM_DB="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [ -z "$ENV" ]; then
    echo "Error: --env argument is required"
    show_help
    exit 1
fi

ENV=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')

# Set RDS variables based on environment
case $ENV in
    DEV)
        HOST="${RDS_DEV_HOST}"
        PORT="${RDS_DEV_PORT}"
        DB="${RDS_DEV_DB}"
        USER="${RDS_DEV_USER}"
        PASS="${RDS_DEV_PASS}"
        ;;
    STG)
        HOST="${RDS_STG_HOST}"
        PORT="${RDS_STG_PORT}"
        DB="${RDS_STG_DB}"
        USER="${RDS_STG_USER}"
        PASS="${RDS_STG_PASS}"
        ;;
    PROD)
        HOST="${RDS_PROD_HOST}"
        PORT="${RDS_PROD_PORT}"
        DB="${RDS_PROD_DB}"
        USER="${RDS_PROD_USER}"
        PASS="${RDS_PROD_PASS}"
        ;;
    *)
        echo "Error: Invalid environment '$ENV'. Must be dev, stg, or prod"
        exit 1
        ;;
esac

# Validate required RDS variables
if [ -z "$HOST" ] || [ -z "$USER" ] || [ -z "$PASS" ]; then
    echo "Error: Missing RDS environment variables for $ENV environment"
    echo "Please check your .env file"
    exit 1
fi

# Build RDS connection string
export PGPASSWORD="$PASS"
CONN_STRING="host=$HOST port=$PORT dbname=${CUSTOM_DB:-$DB} user=$USER"

echo "=========================================="
echo "Listing users and permissions in $ENV RDS"
if [ -n "$CUSTOM_DB" ]; then
    echo "Database: $CUSTOM_DB"
fi
echo "=========================================="
echo ""

# List all database roles/users
echo "=== All Database Users/Roles ==="
psql "$CONN_STRING" -c "
SELECT
    usename as \"User Name\",
    usesuper as \"Superuser\",
    usecreatedb as \"Create DB\",
    valuntil as \"Valid Until\"
FROM pg_user
ORDER BY usename;
"

echo ""
echo "=== User Role Memberships ==="
psql "$CONN_STRING" -c "
SELECT
    u.usename as \"User\",
    r.rolname as \"Role\",
    r.rolsuper as \"Role Superuser\",
    r.rolinherit as \"Inherit\"
FROM pg_user u
LEFT JOIN pg_auth_members m ON u.usesysid = m.member
LEFT JOIN pg_roles r ON m.roleid = r.oid
ORDER BY u.usename, r.rolname;
"

# If specific database provided, show table-level permissions
if [ -n "$CUSTOM_DB" ]; then
    echo ""
    echo "=== Table Permissions in $CUSTOM_DB ==="
    psql "$CONN_STRING" -c "
SELECT
    grantee as \"User/Role\",
    table_schema as \"Schema\",
    table_name as \"Table\",
    string_agg(privilege_type, ', ') as \"Permissions\"
FROM information_schema.role_table_grants
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
GROUP BY grantee, table_schema, table_name
ORDER BY grantee, table_schema, table_name;
    "
fi
