#!/bin/bash
set -e

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0"; exit 0 ;;
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

# list pods
kubectl get pods --namespace "$NAMESPACE"
