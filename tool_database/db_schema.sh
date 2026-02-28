#!/bin/bash
# RDS List All Schemas and Tables Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load RDS environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "Error: .env file not found in $SCRIPT_DIR"
    exit 1
fi

# Default values
ENV=""

# Show help
show_help() {
    cat <<EOF
Usage: $0 --env <dev|stg|prod> [OPTIONS]

RDS List All Schemas and Tables Script - Display schemas and tables in RDS database

Required Arguments:
  --env <dev|stg|prod>          Target RDS environment (dev, stg, or prod)

Optional Arguments:
  --help                         Show this help message

Examples:
  # List all schemas and tables in dev RDS
  $0 --env dev

  # List all schemas and tables in staging RDS
  $0 --env stg

  # List all schemas and tables in production RDS
  $0 --env prod

Output:
  Displays all schemas with their associated tables
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV="$2"
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

# Build RDS connection string and execute query
export PGPASSWORD="$PASS"
CONN_STRING="host=$HOST port=$PORT dbname=$DB user=$USER"

echo "=========================================="
echo "Listing schemas and tables in $ENV RDS"
echo "=========================================="
echo ""

# List schemas and their tables
psql "$CONN_STRING" -c "
SELECT
    schema_name,
    tablename as table_name
FROM
    information_schema.schemata
    LEFT JOIN pg_tables ON pg_tables.schemaname = schema_name
WHERE
    schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_internal')
ORDER BY
    schema_name, table_name;
"
