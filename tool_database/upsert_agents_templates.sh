#!/bin/bash
# UPSERT agents.templates from STAGING to PRODUCTION using COPY
# This method preserves all data types and handles complex data better

STG_HOST="${STG_HOST:-stg-pg.cxwaae0iabaq.ap-southeast-5.rds.amazonaws.com}"
STG_USER="${STG_USER:-rds_admin_stg}"
STG_DB="${STG_DB:-agents_stg}"
export PGPASSWORD="${STG_PGPASSWORD:?Error: STG_PGPASSWORD environment variable is required}"

PROD_HOST="${PROD_HOST:-prod-pg.cxwaae0iabaq.ap-southeast-5.rds.amazonaws.com}"
PROD_USER="${PROD_USER:-rds_admin_prod}"
PROD_DB="${PROD_DB:-agents_prod}"

echo "=========================================="
echo "AGENTS TEMPLATES UPSERT (using COPY)"
echo "=========================================="
echo "Source: $STG_HOST/$STG_DB"
echo "Target: $PROD_HOST/$PROD_DB"
echo "Table:  templates"
echo ""

# Backup PROD
echo "[1/4] Backing up PROD agents_prod..."
export PGPASSWORD="${PROD_PGPASSWORD}"
BACKUP="/apps/temp/db_backup/agents_prod_$(date +%Y%m%d_%H%M%S).sql.gz"
mkdir -p /apps/temp/db_backup
pg_dump -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" 2>/dev/null | gzip > "$BACKUP"
echo "✓ Backup: $BACKUP"
echo ""

# Check STAGING templates
export PGPASSWORD="${STG_PGPASSWORD}"
echo "[2/4] Analyzing STAGING templates..."
ROWS=$(psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" -t -c "SELECT COUNT(*) FROM templates;")
echo "✓ Found $ROWS rows"
echo ""

if [[ "$ROWS" == "0" ]]; then
  echo "No data to sync"
  exit 0
fi

read -p "Continue? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then exit 0; fi
echo ""

# Export from STAGING
echo "[3/4] Exporting and importing..."
echo -n "  Exporting from STAGING ... "

psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" \
  -c "\COPY (SELECT * FROM templates) TO STDOUT WITH (FORMAT csv, DELIMITER E'\t')" \
  > /tmp/templates_copy.tsv 2>/dev/null

if [[ ! -s /tmp/templates_copy.tsv ]]; then
  echo "FAILED"
  exit 1
fi
echo "✓"

# Import to PROD
export PGPASSWORD="${PROD_PGPASSWORD}"
echo -n "  Truncating PROD templates ... "
psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" \
  -c "TRUNCATE templates;" > /dev/null 2>&1
echo "✓"

echo -n "  Importing to PROD ... "
psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" \
  -c "\COPY templates FROM STDIN WITH (FORMAT csv, DELIMITER E'\t')" \
  < /tmp/templates_copy.tsv > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
  echo "✓"
else
  echo "FAILED"
  exit 1
fi

# Save backup TSV
cp /tmp/templates_copy.tsv "/apps/temp/db_backup/templates_$(date +%Y%m%d_%H%M%S).tsv" 2>/dev/null

# Verify
echo ""
echo "[4/4] Verification"
export PGPASSWORD="${PROD_PGPASSWORD}"
FINAL_COUNT=$(psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" -t -c "SELECT COUNT(*) FROM templates;")

echo "=========================================="
echo "✅ UPSERT Complete!"
echo "Templates synced: $FINAL_COUNT rows"
echo "Backup:          $BACKUP"
echo "=========================================="

rm -f /tmp/templates_copy.tsv
