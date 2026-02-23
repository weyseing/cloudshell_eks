#!/bin/bash
set -e

# Shell into a running pod.
#
# Usage:
#   ./eks_exec_pod.sh --pod <name> [--container <name>] [--cmd <cmd>]
#
# Defaults:
#   --cmd   /bin/bash

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0 --pod <name> [--container <name>] [--cmd <cmd>]"; exit 0 ;;
    --pod)       POD="$2";       shift ;;
    --container) CONTAINER="$2"; shift ;;
    --cmd)       CMD="$2";       shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$POD" ]]; then
  echo "Usage: $0 --pod <name> [--container <name>] [--cmd <cmd>]"
  exit 1
fi

CMD="${CMD:-/bin/bash}"

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# read namespace from temp file
TEMP_FILE="$(dirname "$0")/../temp/namespace"
if [[ ! -f "$TEMP_FILE" ]]; then
  echo "Warning: namespace not set. Run eks_set_namespace.sh --namespace <namespace> first."
  exit 1
fi
NAMESPACE=$(cat "$TEMP_FILE")

# build container flag
CONTAINER_FLAG=""
[[ -n "$CONTAINER" ]] && CONTAINER_FLAG="-c $CONTAINER"

echo "Exec into pod: $POD (namespace: $NAMESPACE, cmd: $CMD)"
echo ""
kubectl exec -it "$POD" --namespace "$NAMESPACE" $CONTAINER_FLAG -- "$CMD"
