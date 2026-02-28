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


# Check namespace is set
if [[ -z "$EKS_NAMESPACE" ]]; then
  echo "Error: EKS_NAMESPACE not set. Run: . ./eks_set_namespace.sh --namespace <namespace>"
  exit 1
fi
NAMESPACE="$EKS_NAMESPACE"

# build container flag
CONTAINER_FLAG=""
[[ -n "$CONTAINER" ]] && CONTAINER_FLAG="-c $CONTAINER"

echo "Exec into pod: $POD (namespace: $NAMESPACE, cmd: $CMD)"
echo ""
kubectl exec -it "$POD" --namespace "$NAMESPACE" $CONTAINER_FLAG -- "$CMD"
