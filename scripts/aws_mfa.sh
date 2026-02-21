#!/bin/bash
set -e
aws-mfa --device "$AWS_MFA_DEVICE" --profile default
