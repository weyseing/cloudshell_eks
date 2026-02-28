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


# Check namespace is set
if [[ -z "$EKS_NAMESPACE" ]]; then
  echo "Error: EKS_NAMESPACE not set. Run: . ./eks_set_namespace.sh --namespace <namespace>"
  exit 1
fi

# list pods
kubectl get pods --namespace "$EKS_NAMESPACE"
