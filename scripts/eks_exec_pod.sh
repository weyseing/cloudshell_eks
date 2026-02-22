#!/bin/bash
set -e

# Shell into a running pod.
# If multiple pods match a deployment, presents a selection menu.
#
# Usage:
#   By pod name:    ./eks_exec_pod.sh --pod <name> [--container <name>] [--cmd <cmd>]
#   By deployment:  ./eks_exec_pod.sh --deployment <name> [--container <name>] [--cmd <cmd>]
#
# Defaults:
#   --cmd   /bin/sh   (falls back to /bin/bash if sh not found)

CMD_DEFAULT="/bin/sh"

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --pod)        POD="$2";        shift ;;
    --deployment) DEPLOYMENT="$2"; shift ;;
    --container)  CONTAINER="$2";  shift ;;
    --cmd)        CMD="$2";        shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$POD" && -z "$DEPLOYMENT" ]]; then
  echo "Usage: $0 --pod <name> [--container <name>] [--cmd <cmd>]"
  echo "       $0 --deployment <name> [--container <name>] [--cmd <cmd>]"
  exit 1
fi

CMD="${CMD:-$CMD_DEFAULT}"

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# read namespace from temp file
TEMP_FILE="$(dirname "$0")/../temp/namespace"
if [[ ! -f "$TEMP_FILE" ]]; then
  echo "Warning: namespace not set. Run eks_set_namespace.sh --namespace <namespace> first."
  exit 1
fi
NAMESPACE=$(cat "$TEMP_FILE")

# resolve pod from deployment
if [[ -n "$DEPLOYMENT" ]]; then
  SELECTOR=$(kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" \
    -o jsonpath='{.spec.selector.matchLabels}' | \
    python3 -c "
import sys, json
labels = json.loads(sys.stdin.read())
print(','.join(f'{k}={v}' for k,v in labels.items()))
")
  PODS=$(kubectl get pods --namespace "$NAMESPACE" -l "$SELECTOR" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[*].metadata.name}')

  if [[ -z "$PODS" ]]; then
    echo "No running pods found for deployment: $DEPLOYMENT"
    exit 1
  fi

  POD_COUNT=$(echo "$PODS" | wc -w)
  if [[ "$POD_COUNT" -eq 1 ]]; then
    POD="$PODS"
  else
    echo "Multiple pods found for deployment: $DEPLOYMENT"
    echo ""
    PS3="Select pod: "
    select POD in $PODS; do
      [[ -n "$POD" ]] && break || echo "Invalid selection, try again."
    done
  fi
fi

# build container flag
CONTAINER_FLAG=""
[[ -n "$CONTAINER" ]] && CONTAINER_FLAG="-c $CONTAINER"

echo "Exec into pod: $POD (namespace: $NAMESPACE, cmd: $CMD)"
echo ""

# shellcheck disable=SC2086
kubectl exec -it "$POD" --namespace "$NAMESPACE" $CONTAINER_FLAG -- "$CMD"
