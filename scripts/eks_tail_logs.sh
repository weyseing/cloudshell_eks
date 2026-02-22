#!/bin/bash
set -e

# Tail logs from ALL pods belonging to a deployment/service for N seconds
# and save the output to a timestamped local log file.
#
# Usage:
#   ./eks_tail_logs.sh --deployment <name> [--seconds <N>] [--output <dir>]
#   ./eks_tail_logs.sh --service <name>    [--seconds <N>] [--output <dir>]
#
# Defaults:
#   --seconds  60
#   --output   ./logs  (created if it doesn't exist)

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --deployment) DEPLOYMENT="$2"; shift ;;
    --service)    SERVICE="$2";    shift ;;
    --seconds)    DURATION="$2";   shift ;;
    --output)     OUTPUT_DIR="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$DEPLOYMENT" && -z "$SERVICE" ]]; then
  echo "Usage: $0 --deployment <name> [--seconds <N>] [--output <dir>]"
  echo "       $0 --service    <name> [--seconds <N>] [--output <dir>]"
  exit 1
fi

DURATION="${DURATION:-60}"
OUTPUT_DIR="${OUTPUT_DIR:-$(dirname "$0")/../logs}"

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# read namespace from temp file
TEMP_FILE="$(dirname "$0")/../temp/namespace"
if [[ ! -f "$TEMP_FILE" ]]; then
  echo "Warning: namespace not set. Run eks_set_namespace.sh --namespace <namespace> first."
  exit 1
fi
NAMESPACE=$(cat "$TEMP_FILE")

# resolve pod label selector
if [[ -n "$DEPLOYMENT" ]]; then
  TARGET_NAME="$DEPLOYMENT"
  SELECTOR=$(kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" \
    -o jsonpath='{.spec.selector.matchLabels}' | \
    python3 -c "
import sys, json
labels = json.loads(sys.stdin.read())
print(','.join(f'{k}={v}' for k,v in labels.items()))
")
elif [[ -n "$SERVICE" ]]; then
  TARGET_NAME="$SERVICE"
  SELECTOR=$(kubectl get service "$SERVICE" --namespace "$NAMESPACE" \
    -o jsonpath='{.spec.selector}' | \
    python3 -c "
import sys, json
labels = json.loads(sys.stdin.read())
print(','.join(f'{k}={v}' for k,v in labels.items()))
")
fi

if [[ -z "$SELECTOR" ]]; then
  echo "Error: could not determine pod selector for $TARGET_NAME."
  exit 1
fi

# get matching pods
PODS=$(kubectl get pods --namespace "$NAMESPACE" -l "$SELECTOR" \
  -o jsonpath='{.items[*].metadata.name}')

if [[ -z "$PODS" ]]; then
  echo "No running pods found for selector: $SELECTOR"
  exit 1
fi

# prepare output file
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${OUTPUT_DIR}/${TARGET_NAME}_${TIMESTAMP}.log"

echo "Tailing logs for: $TARGET_NAME (namespace: $NAMESPACE)"
echo "Pods  : $PODS"
echo "Duration: ${DURATION}s"
echo "Output  : $LOG_FILE"
echo ""

# write header to log file
{
  echo "# Log capture"
  echo "# Target    : $TARGET_NAME"
  echo "# Namespace : $NAMESPACE"
  echo "# Selector  : $SELECTOR"
  echo "# Pods      : $PODS"
  echo "# Duration  : ${DURATION}s"
  echo "# Started   : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "# ─────────────────────────────────────────────"
} >> "$LOG_FILE"

# start kubectl logs --follow for each pod in background, prefix each line
BG_PIDS=()
for POD in $PODS; do
  kubectl logs --follow --timestamps \
    --namespace "$NAMESPACE" "$POD" 2>&1 | \
    awk -v pod="$POD" '{ print "[" pod "] " $0; fflush() }' \
    >> "$LOG_FILE" &
  BG_PIDS+=($!)
done

echo "Collecting logs... (press Ctrl+C to stop early)"

# run for DURATION seconds then kill background jobs
sleep "$DURATION"

for PID in "${BG_PIDS[@]}"; do
  kill "$PID" 2>/dev/null || true
done
wait 2>/dev/null || true

# write footer
{
  echo "# ─────────────────────────────────────────────"
  echo "# Ended : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} >> "$LOG_FILE"

echo ""
echo "Done. Log saved to: $LOG_FILE"
echo "Lines captured: $(grep -c '' "$LOG_FILE" || true)"
