#!/bin/bash
set -e

# Watch all pods for a deployment in real-time during rollout.
# Shows pod creation, status changes, and restarts as they happen.
#
# Usage:
#   ./eks_watch_pods.sh --deployment <name> [--timeout 5m]
#
# Options:
#   --timeout   Stop watching after specified duration (default: 1m, e.g., 5m, 60s, 2h)

TIMEOUT="20s"

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0 --deployment <name> [--timeout 5m]"; echo "Options:"; echo "  --timeout   Stop watching after specified duration (default: 1m)"; exit 0 ;;
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

# ── watch deployment pods (non-TTY compatible) ─────────────────────────────────
echo "Watching pods for deployment: $DEPLOYMENT (namespace: $NAMESPACE)"
echo "Polling every 2 seconds for changes..."
[[ -n "$TIMEOUT" ]] && echo "Timeout: $TIMEOUT"
echo ""

# Get the label selector for the deployment
SELECTOR=$(kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.selector.matchLabels}' | \
  python3 -c "
import sys, json
labels = json.load(sys.stdin)
print(','.join(f'{k}={v}' for k,v in labels.items()))
")

echo "Label selector: $SELECTOR"
echo ""

PREV_STATE=""
ITERATION=0

# ── polling loop (non-TTY compatible) ──────────────────────────────────────────
run_watch() {
  while true; do
    ITERATION=$((ITERATION + 1))
    CURRENT_STATE=$(kubectl get pods --namespace "$NAMESPACE" -l "$SELECTOR" -o wide 2>&1 || echo "ERROR")

    if [[ "$CURRENT_STATE" != "$PREV_STATE" ]]; then
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] Update #$ITERATION:"
      echo "$CURRENT_STATE"
      echo ""
      PREV_STATE="$CURRENT_STATE"
    fi

    sleep 2
  done
}

# Run with timeout using subshell
if [[ "$TIMEOUT" == "0" ]]; then
  run_watch
else
  timeout "$TIMEOUT" bash -c "$(declare -f run_watch); run_watch"
fi