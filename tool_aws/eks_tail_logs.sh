#!/bin/bash
set -e

# Tail logs from ALL pods belonging to a deployment
# and save the output to temp/logs/<deployment-name>_YYYYMMDD_hhmmss.log
#
# Usage:
#   ./eks_tail_logs.sh --deployment <name> [--timeout 5m]
#
# Options:
#   --timeout   Stop tailing after specified duration (default: 20s, e.g., 5m, 60s, 2h)

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0 --deployment <name> [--timeout 5m]"; echo "Options:"; echo "  --timeout   Stop tailing after specified duration (default: 20s)"; exit 0 ;;
    --deployment) DEPLOYMENT="$2"; shift ;;
    --timeout)    TIMEOUT="$2";    shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$DEPLOYMENT" ]]; then
  echo "Usage: $0 --deployment <name> [--timeout 5m]"
  exit 1
fi

TIMEOUT="${TIMEOUT:-20s}"
OUTPUT_DIR="$(dirname "$0")/../temp/logs"

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# read namespace from temp file
TEMP_FILE="$(dirname "$0")/../temp/namespace"
if [[ ! -f "$TEMP_FILE" ]]; then
  echo "Warning: namespace not set. Run eks_set_namespace.sh --namespace <namespace> first."
  exit 1
fi
NAMESPACE=$(cat "$TEMP_FILE")

# set namespace temporarily, cleanup on exit
kubectl config set-context --current --namespace="$NAMESPACE" > /dev/null 2>&1
trap "kubectl config set-context --current --namespace='' > /dev/null 2>&1" EXIT

# resolve pod label selector from deployment
TARGET_NAME="$DEPLOYMENT"
SELECTOR=$(kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.selector.matchLabels}' | \
  python3 -c "
import sys, json
labels = json.loads(sys.stdin.read())
print(','.join(f'{k}={v}' for k,v in labels.items()))
")

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
echo "Timeout : $TIMEOUT"
echo "Output  : $LOG_FILE"
echo ""

# write header to log file
{
  echo "# Log capture"
  echo "# Target    : $TARGET_NAME"
  echo "# Namespace : $NAMESPACE"
  echo "# Selector  : $SELECTOR"
  echo "# Pods      : $PODS"
  echo "# Timeout   : $TIMEOUT"
  echo "# Started   : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "# ─────────────────────────────────────────────"
} >> "$LOG_FILE"

echo "Collecting logs... (press Ctrl+C to stop early)"

# export variables for subshell
export NAMESPACE PODS LOG_FILE

# run_tail function with timeout
run_tail() {
  for POD in $PODS; do
    kubectl logs -f --timestamps --namespace "$NAMESPACE" "$POD" 2>&1 | \
      awk -v pod="$POD" '{ print "[" pod "] " $0 }' | tee -a "$LOG_FILE" &
  done
  wait
}

# Run with timeout
timeout "$TIMEOUT" bash -c "$(declare -f run_tail); run_tail" || true

# write footer
{
  echo "# ─────────────────────────────────────────────"
  echo "# Ended : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} >> "$LOG_FILE"

echo ""
echo "Done. Log saved to: $LOG_FILE"
echo "Lines captured: $(grep -c '' "$LOG_FILE" || true)"
