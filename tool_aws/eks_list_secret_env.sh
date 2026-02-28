#!/bin/bash
set -e

# List Kubernetes Secrets (names + keys) by secret name or pod.
# Usage:
#   Scoped to secret name:          ./eks_list_secret_env.sh --secret <name>
#   Scoped to pod:                  ./eks_list_secret_env.sh --pod <name>
#
# Note: Secret *values* are base64-encoded in etcd. This script decodes and
#       prints them so you can audit what is actually injected. Run only in
#       environments where you are authorised to view secret values.

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0 [--secret <name>] [--pod <name>]"; exit 0 ;;
    --secret) SECRET="$2"; shift ;;
    --pod)    POD="$2";    shift ;;
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

# ── helper: print decoded key/value pairs for a secret ───────────────────────
print_secret_kv() {
  local SECRET_NAME="$1"
  echo ""
  echo "--- Secret: $SECRET_NAME ---"
  kubectl get secret "$SECRET_NAME" --namespace "$NAMESPACE" -o json | \
    python3 -c "
import sys, json, base64
d = json.load(sys.stdin)
data = d.get('data', {})
if not data:
    print('  (empty / no data keys)')
else:
    for k, v in sorted(data.items()):
        try:
            decoded = base64.b64decode(v).decode('utf-8')
        except Exception:
            decoded = '<binary>'
        print(f'  {k} = {decoded}')
"
}

# ── scoped to secret name ─────────────────────────────────────────────────────
if [[ -n "$SECRET" ]]; then
  echo "Listing secret: $SECRET (namespace: $NAMESPACE)"
  print_secret_kv "$SECRET"
  exit 0
fi

# ── scoped to pod ─────────────────────────────────────────────────────────────
if [[ -n "$POD" ]]; then
  echo "Listing secrets referenced by pod: $POD (namespace: $NAMESPACE)"
  SECRET_NAMES=$(kubectl get pod "$POD" --namespace "$NAMESPACE" -o json | \
    python3 -c "
import sys, json
spec = json.load(sys.stdin)['spec']
names = set()
for c in spec.get('containers', []) + spec.get('initContainers', []):
    for ef in c.get('envFrom', []):
        n = ef.get('secretRef', {}).get('name', '')
        if n: names.add(n)
    for e in c.get('env', []):
        n = e.get('valueFrom', {}).get('secretKeyRef', {}).get('name', '')
        if n: names.add(n)
for n in sorted(names): print(n)
")
  if [[ -z "$SECRET_NAMES" ]]; then
    echo "No secrets referenced by this pod."
    exit 0
  fi
  for NAME in $SECRET_NAMES; do
    print_secret_kv "$NAME"
  done
  exit 0
fi

# ── error: must specify either --pod or --secret ────────────────────────────
echo "Error: must specify either --pod <pod_name> or --secret <secret_name>"
exit 1
