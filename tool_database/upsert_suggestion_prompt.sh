#!/bin/bash
# UPSERT suggestion_prompt template from STAGING to PRODUCTION
# Clones ilmu_chat_stg_v2 → ilmu_chat_prod for suggestion_prompt

STG_HOST="${STG_HOST:-stg-pg.cxwaae0iabaq.ap-southeast-5.rds.amazonaws.com}"
STG_USER="${STG_USER:-rds_admin_stg}"
STG_DB="${STG_DB:-ilmu_chat_stg_v2}"
export PGPASSWORD="${STG_PGPASSWORD:?Error: STG_PGPASSWORD environment variable is required}"

PROD_HOST="${PROD_HOST:-prod-pg.cxwaae0iabaq.ap-southeast-5.rds.amazonaws.com}"
PROD_USER="${PROD_USER:-rds_admin_prod}"
PROD_DB="${PROD_DB:-ilmu_chat_prod}"

echo "=========================================="
echo "SUGGESTION_PROMPT TEMPLATE UPSERT"
echo "=========================================="
echo "Source: $STG_HOST/$STG_DB"
echo "Target: $PROD_HOST/$PROD_DB"
echo "Template: suggestion_prompt"
echo ""

# Check STAGING data
export PGPASSWORD="${STG_PGPASSWORD}"
echo "[1/3] Analyzing STAGING suggestion_prompts..."

# Look for suggestion_prompts records
TEMPLATE_COUNT=$(psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" -t -c \
  "SELECT COUNT(*) FROM suggestion_prompts;" 2>/dev/null)

echo "✓ Found $TEMPLATE_COUNT suggestion_prompts record(s)"
echo ""

if [[ "$TEMPLATE_COUNT" == "0" ]]; then
  echo "No suggestion_prompt data found in staging"
  exit 0
fi

read -p "Continue? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then exit 0; fi
echo ""

# Export suggestion_prompts from STAGING
echo "[2/3] Exporting and importing..."
echo -n "  Exporting from STAGING ... "

psql -h "$STG_HOST" -U "$STG_USER" -d "$STG_DB" \
  -c "\COPY (SELECT * FROM suggestion_prompts) TO STDOUT WITH (FORMAT csv, DELIMITER E'\t')" \
  > /tmp/suggestion_prompts.tsv 2>/dev/null

if [[ ! -s /tmp/suggestion_prompts.tsv ]]; then
  echo "FAILED"
  exit 1
fi
echo "✓"

# Get column names for proper INSERT statement
export PGPASSWORD="${PROD_PGPASSWORD}"
COLS=$(psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" -t -c \
  "SELECT STRING_AGG(column_name, ', ') FROM information_schema.columns WHERE table_name='suggestion_prompts' ORDER BY ordinal_position;" 2>/dev/null)

echo -n "  Importing to PROD ... "
psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" \
  -c "\COPY suggestion_prompts ($COLS) FROM STDIN WITH (FORMAT csv, DELIMITER E'\t')" \
  < /tmp/suggestion_prompts.tsv > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
  echo "✓"
else
  echo "FAILED"
  exit 1
fi

# Save backup TSV
cp /tmp/suggestion_prompts.tsv "/tmp/db_backup/suggestion_prompts_$(date +%Y%m%d_%H%M%S).tsv" 2>/dev/null

# Verify
echo ""
echo "[3/3] Verification"
export PGPASSWORD="${PROD_PGPASSWORD}"
FINAL_COUNT=$(psql -h "$PROD_HOST" -U "$PROD_USER" -d "$PROD_DB" -t -c \
  "SELECT COUNT(*) FROM suggestion_prompts;" 2>/dev/null)

echo "=========================================="
echo "✅ UPSERT Complete!"
echo "suggestion_prompts records synced: $FINAL_COUNT"
echo "=========================================="

rm -f /tmp/suggestion_prompts.tsv
