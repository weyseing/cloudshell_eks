#!/bin/bash
# RDS Database Connection Script
# Connect to RDS databases in interactive or non-interactive mode

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
MODE="tty"
COMMAND=""

# Show help
show_help() {
    cat <<EOF
Usage: $0 --env <dev|stg|prod> [OPTIONS]

RDS Database Connection Script - Connect to RDS in interactive or non-interactive mode

Required Arguments:
  --env <dev|stg|prod>          Target RDS environment (dev, stg, or prod)

Mode Arguments (choose one):
  --tty                          Interactive mode (default, connect to psql shell)
  --exec                         Execution mode (execute command only, exit after)

Optional Arguments:
  --command <sql>                SQL command to execute (required with --exec)
  --help                         Show this help message

Examples:
  # Interactive connection to dev RDS
  $0 --env dev --tty

  # Execution mode: execute query and exit
  $0 --env dev --exec --command "SELECT version();"

  # Non-interactive: run SQL file
  psql \$(DB_CONNECTION_STRING) < script.sql
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV="$2"
            shift 2
            ;;
        --tty)
            MODE="tty"
            shift
            ;;
        --exec)
            MODE="exec"
            shift
            ;;
        --command)
            COMMAND="$2"
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
CONN_STRING="host=$HOST port=$PORT dbname=$DB user=$USER"

# Execute based on mode
if [ "$MODE" = "tty" ]; then
    echo "Connecting to $ENV RDS database..."
    psql "$CONN_STRING"
else
    if [ -z "$COMMAND" ]; then
        echo "Error: --command is required when using --exec"
        exit 1
    fi
    psql "$CONN_STRING" -c "$COMMAND"
fi
