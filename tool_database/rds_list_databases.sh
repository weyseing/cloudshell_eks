#!/bin/bash
set -e

# Parse arguments
ENV=${1:-dev}
USER_TYPE=${2:-admin}

show_help() {
  cat << EOF
Usage: $0 <environment> <user-type> [options]

Arguments:
  environment    {dev|stg|prod}  RDS environment
  user-type      {admin|migration}  User type for connection

Options:
  --user USER           Database user (overrides env config)
  --pass PASSWORD       Database password (overrides env config)
  --host HOST           Database host (overrides env config)
  --port PORT           Database port (overrides env config)
  -h, --help            Show this help message

Examples:
  $0 dev admin
  $0 stg migration
  $0 prod admin --user custom_user --pass mypass

EOF
}

# Override variables for optional args
OVERRIDE_USER=""
OVERRIDE_PASSWORD=""
OVERRIDE_HOST=""
OVERRIDE_PORT=""

# Check for help flag first
if [[ "$ENV" == "-h" ]] || [[ "$ENV" == "--help" ]]; then
  show_help
  exit 0
fi

# Process additional arguments
while [[ "$#" -gt 2 ]]; do
  case $3 in
    --user) OVERRIDE_USER="$4"; shift 2 ;;
    --pass|--password) OVERRIDE_PASSWORD="$4"; shift 2 ;;
    --host) OVERRIDE_HOST="$4"; shift 2 ;;
    --port) OVERRIDE_PORT="$4"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown parameter: $3"; show_help; exit 1 ;;
  esac
done

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
        show_help
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
    show_help
    exit 1
    ;;
esac

if [ -z "$HOST" ] || [ -z "$USER" ]; then
  echo "Error: RDS configuration for ${ENV}_${USER_TYPE} not configured in .env"
  exit 1
fi

# Apply overrides
HOST="${OVERRIDE_HOST:-$HOST}"
PORT="${OVERRIDE_PORT:-$PORT}"
USER="${OVERRIDE_USER:-$USER}"
PASSWORD="${OVERRIDE_PASSWORD:-$PASSWORD}"

echo "Listing databases on RDS $ENV as $USER_TYPE..."
PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -l
