#!/bin/bash
set -e

# Parse arguments
ENV=""
USER_TYPE=""
DATABASE=""
SCHEMA="public"

show_help() {
  cat << EOF
Usage: $0 <environment> <user-type> [options]

Arguments:
  environment    {dev|stg|prod}  RDS environment
  user-type      {admin|migration}  User type for connection

Options:
  -d, --database NAME   Database name (required)
  -s, --schema NAME     Schema name (default: public)
  --user USER           Database user (overrides env config)
  --pass PASSWORD       Database password (overrides env config)
  --host HOST           Database host (overrides env config)
  --port PORT           Database port (overrides env config)
  -h, --help            Show this help message

Examples:
  $0 dev admin --database agents_dev
  $0 stg migration --database agents_stg --schema public
  $0 prod admin --database agents_prod --schema custom_schema
  $0 dev admin --database agents_dev --user custom_user --pass mypass

EOF
}

# Override variables for optional args
OVERRIDE_USER=""
OVERRIDE_PASSWORD=""
OVERRIDE_HOST=""
OVERRIDE_PORT=""

# Parse positional arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help) show_help; exit 0 ;;
    -d|--database) DATABASE="$2"; shift 2 ;;
    -s|--schema) SCHEMA="$2"; shift 2 ;;
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

if [ -z "$DATABASE" ]; then
  echo "Error: Database name is required"
  show_help
  exit 1
fi

case $ENV in
  dev|stg|prod)
    ENV_UPPER=$(echo $ENV | tr '[:lower:]' '[:upper:]')
    HOST_VAR="RDS_${ENV_UPPER}_HOST"
    PORT_VAR="RDS_${ENV_UPPER}_PORT"

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

# Apply overrides
HOST="${OVERRIDE_HOST:-$HOST}"
PORT="${OVERRIDE_PORT:-$PORT}"
USER="${OVERRIDE_USER:-$USER}"
PASSWORD="${OVERRIDE_PASSWORD:-$PASSWORD}"

echo "Listing tables in RDS $ENV/$DATABASE/$SCHEMA as $USER_TYPE..."
PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DATABASE" -c "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = '$SCHEMA'
  ORDER BY table_name;"
