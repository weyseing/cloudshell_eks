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

# Default values
DEFAULT_TIMEOUT="10s"
OUTPUT_DIR="$(dirname "$0")/../temp/logs"

# Parse arguments
TIMEOUT="$DEFAULT_TIMEOUT"
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help)
      echo "Usage: $0 --deployment <name> [--timeout 5m]"
      echo "Options:"
      echo "  --timeout   Stop tailing after specified duration (default: $DEFAULT_TIMEOUT)"
      exit 0
      ;;
    --deployment) DEPLOYMENT="$2"; shift ;;
    --timeout)    TIMEOUT="$2";    shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Validate inputs
if [[ -z "$DEPLOYMENT" ]]; then
  echo "Usage: $0 --deployment <name> [--timeout 5m]"
  exit 1
fi

if [[ -z "$EKS_NAMESPACE" ]]; then
  echo "Error: EKS_NAMESPACE not set. Run: . ./eks_set_namespace.sh --namespace <namespace>"
  exit 1
fi

NAMESPACE="$EKS_NAMESPACE"

# Verify deployment exists
kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" > /dev/null || exit 1

# Prepare output file
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${OUTPUT_DIR}/${DEPLOYMENT}_${TIMESTAMP}.log"

echo "Tailing logs for: $DEPLOYMENT (namespace: $NAMESPACE)"
echo "Timeout : $TIMEOUT"
echo "Output  : $LOG_FILE"
echo ""

# Write header to log file
{
  echo "# Log capture for deployment: $DEPLOYMENT"
  echo "# Namespace : $NAMESPACE"
  echo "# Timeout   : $TIMEOUT"
  echo "# Started   : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} > "$LOG_FILE"

echo "Collecting logs... (press Ctrl+C to stop early)"

# Extract label selector from deployment
SELECTOR=$(kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.selector.matchLabels}' \
  | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')

if [[ -z "$SELECTOR" ]]; then
  echo "Error: could not determine pod selector for $DEPLOYMENT."
  exit 1
fi

# Colorize output: cyan for pod names, yellow for timestamps, red for error levels
colorize() {
  sed 's/^\[pod\/\([^\]]*\)\]/\x1b[36m[pod\/\1]\x1b[0m/' | \
  sed 's/ \([0-9T:Z.-]*\) / \x1b[33m\1\x1b[0m /' | \
  sed 's/\(WARNING\|WARN\|ERROR\|FATAL\|CRITICAL\)/\x1b[31m\1\x1b[0m/g'
}

# Tail logs using kubectl's native label selector and --prefix option
if [[ -n "$TIMEOUT" && "$TIMEOUT" != "0" ]]; then
  timeout "$TIMEOUT" kubectl logs -f --timestamps --namespace "$NAMESPACE" \
    -l "$SELECTOR" \
    --max-log-requests=20 --prefix=true 2>&1 | tee -a "$LOG_FILE" | colorize || true
else
  kubectl logs -f --timestamps --namespace "$NAMESPACE" \
    -l "$SELECTOR" \
    --max-log-requests=20 --prefix=true 2>&1 | tee -a "$LOG_FILE" | colorize
fi

# Write footer
{
  echo "# Ended : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} >> "$LOG_FILE"

echo ""
echo "Done. Log saved to: $LOG_FILE"
echo "Lines captured: $(wc -l < "$LOG_FILE" 2>/dev/null || echo "unknown")"
