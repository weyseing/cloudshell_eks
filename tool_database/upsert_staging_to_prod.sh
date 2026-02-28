#!/bin/bash
# UPSERT staging data to production database
# Uses INSERT ... ON CONFLICT DO UPDATE for true UPSERT behavior

STG_HOST="${STG_HOST:-stg-pg.cxwaae0iabaq.ap-southeast-5.rds.amazonaws.com}"
STG_USER="${STG_USER:-rds_admin_stg}"
STG_DB="${STG_DB:-ilmu_wrapper_stg}"
export PGPASSWORD="${STG_PGPASSWORD:?Error: STG_PGPASSWORD environment variable is required}"

PROD_HOST="${PROD_HOST:-prod-pg.cxwaae0iabaq.ap-southeast-5.rds.amazonaws.com}"
PROD_USER="${PROD_USER:-rds_admin_prod}"
PROD_DB="${PROD_DB:-ilmu_wrapper_prod}"

echo "=========================================="
echo "STAGING → PRODUCTION TRUE UPSERT"
echo "=========================================="
echo "Source: $STG_HOST/$STG_DB"
echo "Target: $PROD_HOST/$PROD_DB"
echo ""

# Backup PROD
echo "[1/4] Backing up PROD..."
export PGPASSWORD="${PROD_PGPASSWORD:?Error: PROD_PGPASSWORD environment variable is required}"
BACKUP="/apps/temp/db_backup/prod_$(date +%Y%m%d_%H%M%S).sql.gz"
mkdir -p /apps/temp/db_backup
pg_dump -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" 2>/dev/null | gzip > "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

# Get tables
export PGPASSWORD="${STG_PGPASSWORD}"
echo "[2/4] Analyzing tables..."
TABLES=$(psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" -t -c \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;")
echo "$TABLES" | sed 's/^/  /'
echo ""

read -p "Continue UPSERT? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then exit 0; fi
echo ""

# Step 3: Sync each table with proper UPSERT
echo "[3/4] Executing UPSERT..."
SYNCED=0
FAILED=0

echo "$TABLES" | while read TABLE; do
  TABLE=$(echo "$TABLE" | xargs)
  [[ -z "$TABLE" ]] && continue

  echo -n "  $TABLE ... "

  # Get row count and primary key from staging
  export PGPASSWORD="${STG_PGPASSWORD}"
  ROWS=$(psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" -t -c "SELECT COUNT(*) FROM $TABLE;")

  if [[ "$ROWS" == "0" ]]; then
    echo "empty"
    continue
  fi

  # Get primary key columns
  PK_COLS=$(psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" -t -c \
    "SELECT STRING_AGG(a.attname, ', ')
     FROM pg_index i
     JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
     WHERE i.indrelid = '$TABLE'::regclass AND i.indisprimary;")

  # Get all column names
  ALL_COLS=$(psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" -t -c \
    "SELECT STRING_AGG(column_name, ', ')
     FROM (SELECT column_name FROM information_schema.columns
           WHERE table_name = '$TABLE'
           ORDER BY ordinal_position) t;")

  if [[ -z "$ALL_COLS" ]]; then
    echo "failed to get columns"
    ((FAILED++))
    continue
  fi

  # Export data
  psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" -c "\COPY $TABLE TO STDOUT;" > /tmp/${TABLE}.tmp 2>/dev/null

  if [[ ! -s /tmp/${TABLE}.tmp ]]; then
    echo "export failed"
    ((FAILED++))
    continue
  fi

  # Build UPSERT command
  export PGPASSWORD="${PROD_PGPASSWORD}"

  if [[ -n "$PK_COLS" ]]; then
    # Has primary key - use ON CONFLICT DO UPDATE
    UPDATE_COLS=$(echo "$ALL_COLS" | tr ',' '\n' | sed 's/^[[:space:]]*\(.*\)[[:space:]]*$/\1 = EXCLUDED.\1/' | paste -sd ',' - | sed 's/,/, /g')

    {
      echo "INSERT INTO $TABLE ($ALL_COLS) OVERRIDING SYSTEM VALUE VALUES"
      # Convert TSV to SQL INSERT statements
      awk -F$'\t' -v cols="$ALL_COLS" '
      {
        printf "("
        for(i=1; i<=NF; i++) {
          if ($i ~ /^[0-9]+$|^[0-9]*\.[0-9]+$|^true$|^false$|^$/) {
            printf "%s", ($i == "" ? "NULL" : $i)
          } else {
            gsub(/'"'"'/, "'"'"''"'"'", $i)
            printf "'"'"'%s'"'"'", $i
          }
          if (i < NF) printf ", "
        }
        printf "), "
      }
      END { printf "\b\b \n" }
      ' /tmp/${TABLE}.tmp
      echo "ON CONFLICT ($PK_COLS) DO UPDATE SET $UPDATE_COLS;"
    } | psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" 2>&1 | tail -1

  else
    # No primary key - just insert (will append)
    {
      echo "INSERT INTO $TABLE ($ALL_COLS) VALUES"
      awk -F$'\t' -v cols="$ALL_COLS" '
      {
        printf "("
        for(i=1; i<=NF; i++) {
          if ($i ~ /^[0-9]+$|^[0-9]*\.[0-9]+$|^true$|^false$|^$/) {
            printf "%s", ($i == "" ? "NULL" : $i)
          } else {
            gsub(/'"'"'/, "'"'"''"'"'", $i)
            printf "'"'"'%s'"'"'", $i
          }
          if (i < NF) printf ", "
        }
        printf "), "
      }
      END { printf "\b\b \n" }
      ' /tmp/${TABLE}.tmp
      echo ";"
    } | psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" 2>&1 | tail -1
  fi

  if [[ $? -eq 0 ]]; then
    echo "✓ ($ROWS rows)"
    ((SYNCED++))
    # Save TSV for reference
    cp /tmp/${TABLE}.tmp "/apps/temp/db_backup/${TABLE}.tsv" 2>/dev/null
  else
    echo "✗"
    ((FAILED++))
  fi

  rm -f /tmp/${TABLE}.tmp
done

echo ""
echo "[4/4] Summary"
echo "=========================================="
export PGPASSWORD="${PROD_PGPASSWORD}"
psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" -c \
"SELECT relname as table_name, n_live_tup::integer as rows
 FROM pg_stat_user_tables
 ORDER BY relname;"
echo ""
echo "Backup: $BACKUP"
echo "✅ UPSERT Complete!"
