#!/bin/bash
set -e

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# list eks clusters
aws eks list-clusters --region $AWS_DEFAULT_REGION
