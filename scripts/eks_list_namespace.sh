#!/bin/bash
set -e

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# get namespaces
kubectl get namespaces