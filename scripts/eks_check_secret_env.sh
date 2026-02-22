#!/bin/bash
set -e

# Check which secret env vars are referenced by a deployment or pod.
# Usage:
#   By deployment:  ./eks_check_secret_env.sh --deployment <name>
#   By pod:         ./eks_check_secret_env.sh --pod <name>

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --deployment) DEPLOYMENT="$2"; shift ;;
    --pod)        POD="$2";        shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$DEPLOYMENT" && -z "$POD" ]]; then
  echo "Usage: $0 --deployment <name>"
  echo "       $0 --pod <name>"
  exit 1
fi

# aws assume role
source "$(dirname "$0")/aws_assume_role.sh"

# read namespace from temp file
TEMP_FILE="$(dirname "$0")/../temp/namespace"
if [[ ! -f "$TEMP_FILE" ]]; then
  echo "Warning: namespace not set. Run eks_set_namespace.sh --namespace <namespace> first."
  exit 1
fi
NAMESPACE=$(cat "$TEMP_FILE")

# ── helper: print env-from-secret entries in a container spec ────────────────
print_secret_refs() {
  local JSON="$1"
  local LABEL="$2"

  echo ""
  echo "=== $LABEL ==="

  # envFrom: secretRef
  SECRET_NAMES=$(echo "$JSON" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
containers = (
    data.get('spec', {}).get('containers', []) +
    data.get('spec', {}).get('initContainers', [])
)
for c in containers:
    for ef in c.get('envFrom', []):
        sr = ef.get('secretRef', {})
        name = sr.get('name', '')
        if name:
            print(f'  container={c[\"name\"]}  secretRef={name}')
" 2>/dev/null || true)

  # env[].valueFrom.secretKeyRef
  KEY_REFS=$(echo "$JSON" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
containers = (
    data.get('spec', {}).get('containers', []) +
    data.get('spec', {}).get('initContainers', [])
)
for c in containers:
    for e in c.get('env', []):
        skr = e.get('valueFrom', {}).get('secretKeyRef', {})
        if skr:
            print(f'  container={c[\"name\"]}  envVar={e[\"name\"]}  secret={skr[\"name\"]}  key={skr[\"key\"]}')
" 2>/dev/null || true)

  if [[ -z "$SECRET_NAMES" && -z "$KEY_REFS" ]]; then
    echo "  (no secret env references found)"
  else
    [[ -n "$SECRET_NAMES" ]] && echo "  [envFrom / secretRef]" && echo "$SECRET_NAMES"
    [[ -n "$KEY_REFS"     ]] && echo "  [env / secretKeyRef]"  && echo "$KEY_REFS"
  fi
}

# ── deployment path ───────────────────────────────────────────────────────────
if [[ -n "$DEPLOYMENT" ]]; then
  echo "Checking secret env references for deployment: $DEPLOYMENT (namespace: $NAMESPACE)"
  JSON=$(kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" -o json)
  # deployment spec lives under spec.template.spec
  CONTAINER_JSON=$(echo "$JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(json.dumps(d['spec']['template']))
")
  print_secret_refs "$CONTAINER_JSON" "Deployment: $DEPLOYMENT"
fi

# ── pod path ──────────────────────────────────────────────────────────────────
if [[ -n "$POD" ]]; then
  echo "Checking secret env references for pod: $POD (namespace: $NAMESPACE)"
  JSON=$(kubectl get pod "$POD" --namespace "$NAMESPACE" -o json)
  print_secret_refs "$JSON" "Pod: $POD"
fi
