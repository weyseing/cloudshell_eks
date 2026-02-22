#!/bin/bash
set -e

# Show live CPU and memory usage for pods in the current namespace.
# Optionally scope to a specific deployment, or sort by cpu/memory.
#
# Usage:
#   All pods:             ./eks_top_pod.sh
#   Scoped to deployment: ./eks_top_pod.sh --deployment <name>
#   Sort by memory:       ./eks_top_pod.sh --sort memory
#   Sort by cpu:          ./eks_top_pod.sh --sort cpu   (default)
#   Watch mode:           ./eks_top_pod.sh --watch

SORT_BY="cpu"
WATCH=false

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --deployment) DEPLOYMENT="$2"; shift ;;
    --sort)       SORT_BY="$2";    shift ;;
    --watch)      WATCH=true ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# read namespace from temp file
TEMP_FILE="$(dirname "$0")/../temp/namespace"
if [[ ! -f "$TEMP_FILE" ]]; then
  echo "Warning: namespace not set. Run eks_set_namespace.sh --namespace <namespace> first."
  exit 1
fi
NAMESPACE=$(cat "$TEMP_FILE")

# build label selector if scoped to deployment
SELECTOR_FLAG=""
if [[ -n "$DEPLOYMENT" ]]; then
  SELECTOR=$(kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" \
    -o jsonpath='{.spec.selector.matchLabels}' | \
    python3 -c "
import sys, json
labels = json.load(sys.stdin)
print(','.join(f'{k}={v}' for k,v in labels.items()))
")
  SELECTOR_FLAG="-l $SELECTOR"
  echo "CPU/Memory usage for deployment: $DEPLOYMENT (namespace: $NAMESPACE)"
else
  echo "CPU/Memory usage for all pods (namespace: $NAMESPACE)"
fi

echo "Sorted by: $SORT_BY"
echo ""

run_top() {
  # shellcheck disable=SC2086
  kubectl top pods --namespace "$NAMESPACE" $SELECTOR_FLAG --sort-by="$SORT_BY" 2>/dev/null || {
    echo "Error: metrics-server may not be installed on this cluster."
    echo "Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    exit 1
  }
}

if [[ "$WATCH" == true ]]; then
  echo "Watching (Ctrl+C to exit)..."
  echo ""
  while true; do
    clear
    echo "CPU/Memory usage — namespace: $NAMESPACE — $(date -u +"%H:%M:%S UTC")"
    [[ -n "$DEPLOYMENT" ]] && echo "Deployment: $DEPLOYMENT"
    echo ""
    run_top
    sleep 5
  done
else
  run_top
  echo ""
  echo "Tip: re-run with --watch to refresh every 5s."
fi
