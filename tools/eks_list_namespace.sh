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

# get namespaces
kubectl get namespaces