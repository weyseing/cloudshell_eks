#!/bin/bash
# RDS List All Tables Script

set -e

# Default values (RDS env vars from Docker container)
ENV=""
CUSTOM_DB=""

# Show help
show_help() {
    cat <<EOF
Usage: $0 --env <dev|stg|prod> [OPTIONS]

RDS List All Tables Script - Display all tables in each schema of RDS database

Required Arguments:
  --env <dev|stg|prod>          Target RDS environment (dev, stg, or prod)

Optional Arguments:
  --db <database>               Specific database to list tables from
  --help                        Show this help message

Examples:
  # List all tables in dev RDS (default database)
  $0 --env dev

  # List all tables in specific database
  $0 --env dev --db agents_dev

  # List all tables in staging RDS
  $0 --env stg

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

# Build RDS connection string and execute query
export PGPASSWORD="$PASS"
# Use custom database if provided, otherwise use default
DB=${CUSTOM_DB:-$DB}
CONN_STRING="host=$HOST port=$PORT dbname=$DB user=$USER"

echo "=========================================="
echo "Listing all tables in $ENV RDS - Database: $DB"
echo "=========================================="
echo ""

# List all tables grouped by schema
psql "$CONN_STRING" -c "
SELECT
    schemaname as \"Schema\",
    tablename as \"Table Name\",
    tableowner as \"Owner\"
FROM
    pg_tables
WHERE
    schemaname NOT IN ('pg_catalog', 'information_schema', 'pg_internal')
ORDER BY
    schemaname, tablename;
"
