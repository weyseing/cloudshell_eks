#!/bin/bash
set -e

# Parse arguments
ENV=""
USER_TYPE=""
QUERY=""
FILE=""
DATABASE=""

show_help() {
  cat << EOF
Usage: $0 <environment> <user-type> [options]

Arguments:
  environment    {dev|stg|prod}  RDS environment
  user-type      {admin|migration}  User type for connection

Options:
  -q, --query SQL       SQL query to execute
  -f, --file PATH       SQL file to execute
  -d, --database NAME   Database name (required)
  --user USER           Database user (overrides env config)
  --pass PASSWORD       Database password (overrides env config)
  --host HOST           Database host (overrides env config)
  --port PORT           Database port (overrides env config)
  -h, --help            Show this help message

Note: Either --query or --file is required

Examples:
  $0 dev admin --query "SELECT version();" --database agents_dev
  $0 stg migration --file migrations/001_init.sql --database agents_stg
  $0 prod admin --query "INSERT INTO users VALUES (1, 'test');" --database agents_prod
  $0 dev admin --database agents_dev --query "SELECT 1;" --user custom_user --pass mypass

EOF
}

# Override variables for optional args
OVERRIDE_USER=""
OVERRIDE_PASSWORD=""
OVERRIDE_HOST=""
OVERRIDE_PORT=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help) show_help; exit 0 ;;
    -q|--query) QUERY="$2"; shift 2 ;;
    -f|--file) FILE="$2"; shift 2 ;;
    -d|--database) DATABASE="$2"; shift 2 ;;
    --user) OVERRIDE_USER="$2"; shift 2 ;;
    --pass|--password) OVERRIDE_PASSWORD="$2"; shift 2 ;;
    --host) OVERRIDE_HOST="$2"; shift 2 ;;
    --port) OVERRIDE_PORT="$2"; shift 2 ;;
    dev|stg|prod)
      if [ -z "$ENV" ]; then
        ENV="$1"
      else
        echo "Error: Environment already specified"
        exit 1
      fi
      shift
      ;;
    admin|migration)
      if [ -z "$USER_TYPE" ]; then
        USER_TYPE="$1"
      else
        echo "Error: User type already specified"
        exit 1
      fi
      shift
      ;;
    *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
  esac
done

# Set defaults
ENV=${ENV:-dev}
USER_TYPE=${USER_TYPE:-admin}

case $ENV in
  dev|stg|prod)
    ENV_UPPER=$(echo $ENV | tr '[:lower:]' '[:upper:]')
    HOST_VAR="RDS_${ENV_UPPER}_HOST"
    PORT_VAR="RDS_${ENV_UPPER}_PORT"
    DATABASE_VAR="RDS_${ENV_UPPER}_DATABASE"

    case $USER_TYPE in
      admin)
        USER_VAR="RDS_${ENV_UPPER}_ADMIN_USER"
        PASSWORD_VAR="RDS_${ENV_UPPER}_ADMIN_PASSWORD"
        ;;
      migration)
        USER_VAR="RDS_${ENV_UPPER}_MIGRATION_USER"
        PASSWORD_VAR="RDS_${ENV_UPPER}_MIGRATION_PASSWORD"
        ;;
      *)
        echo "Error: Invalid user-type '$USER_TYPE'. Must be 'admin' or 'migration'"
        exit 1
        ;;
    esac

    HOST="${!HOST_VAR}"
    PORT="${!PORT_VAR}"
    USER="${!USER_VAR}"
    PASSWORD="${!PASSWORD_VAR}"
    DATABASE="${!DATABASE_VAR}"
    ;;
  *)
    echo "Error: Invalid environment '$ENV'. Must be 'dev', 'stg', or 'prod'"
    exit 1
    ;;
esac

if [ -z "$HOST" ] || [ -z "$USER" ]; then
  echo "Error: RDS configuration not found in .env"
  exit 1
fi

if [ -z "$DATABASE" ]; then
  echo "Error: Database name is required"
  show_help
  exit 1
fi

if [ -n "$FILE" ]; then
  if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found"
    exit 1
  fi
  QUERY=$(cat "$FILE")
fi

if [ -z "$QUERY" ]; then
  echo "Error: Query required. Use --query 'SELECT ...' or --file file.sql"
  show_help
  exit 1
fi

# Apply overrides
HOST="${OVERRIDE_HOST:-$HOST}"
PORT="${OVERRIDE_PORT:-$PORT}"
USER="${OVERRIDE_USER:-$USER}"
PASSWORD="${OVERRIDE_PASSWORD:-$PASSWORD}"

echo "Executing on RDS $ENV/$DATABASE as $USER_TYPE..."
PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DATABASE" -c "$QUERY"
