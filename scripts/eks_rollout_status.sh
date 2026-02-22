#!/bin/bash
set -e

# Watch rollout progress for a deployment until complete or failed.
# Also shows rollout history and current replica status.
#
# Usage:
#   ./eks_rollout_status.sh --deployment <name> [--watch]
#
# Flags:
#   --watch   stream live status until rollout finishes (default: show once)

# get args
WATCH=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --deployment) DEPLOYMENT="$2"; shift ;;
    --watch)      WATCH=true ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$DEPLOYMENT" ]]; then
  echo "Usage: $0 --deployment <name> [--watch]"
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

echo "=== Rollout history: $DEPLOYMENT (namespace: $NAMESPACE) ==="
kubectl rollout history deployment/"$DEPLOYMENT" --namespace "$NAMESPACE"

echo ""
echo "=== Replica status ==="
kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" \
  -o custom-columns=\
"NAME:.metadata.name,\
DESIRED:.spec.replicas,\
READY:.status.readyReplicas,\
UPDATED:.status.updatedReplicas,\
AVAILABLE:.status.availableReplicas"

echo ""
echo "=== Pod status ==="
SELECTOR=$(kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.selector.matchLabels}' | \
  python3 -c "
import sys, json
labels = json.loads(sys.stdin.read())
print(','.join(f'{k}={v}' for k,v in labels.items()))
")
kubectl get pods --namespace "$NAMESPACE" -l "$SELECTOR" \
  -o custom-columns=\
"NAME:.metadata.name,\
STATUS:.status.phase,\
READY:.status.conditions[?(@.type=='Ready')].status,\
RESTARTS:.status.containerStatuses[0].restartCount,\
AGE:.metadata.creationTimestamp"

echo ""
if [[ "$WATCH" == true ]]; then
  echo "=== Watching rollout (Ctrl+C to exit) ==="
  kubectl rollout status deployment/"$DEPLOYMENT" --namespace "$NAMESPACE" --watch
else
  echo "=== Rollout status ==="
  kubectl rollout status deployment/"$DEPLOYMENT" --namespace "$NAMESPACE"
  echo ""
  echo "Tip: re-run with --watch to stream live progress."
fi
