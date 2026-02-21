#!/bin/bash
set -e

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --cluster) CLUSTER_NAME="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# check args
if [[ -z "$CLUSTER_NAME" ]]; then
  echo "Usage: $0 --cluster <cluster-name>"
  exit 1
fi

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# update kubeconfig — persists cluster context to ~/.kube/config
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION"

echo "Cluster set to: $CLUSTER_NAME"
