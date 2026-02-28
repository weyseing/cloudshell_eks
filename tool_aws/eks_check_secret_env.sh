#!/bin/bash
set -e

# Check which secret env vars are referenced by a deployment or pod.
# Usage:
#   By deployment:  ./eks_check_secret_env.sh --deployment <name>
#   By pod:         ./eks_check_secret_env.sh --pod <name>

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0 --deployment <name>"; echo "       $0 --pod <name>"; exit 0 ;;
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
  echo -e "\e[36m=== $LABEL ===\e[0m"

  echo "$JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
containers = (
    data.get('spec', {}).get('containers', []) +
    data.get('spec', {}).get('initContainers', [])
)
env_from, key_refs = [], []
for c in containers:
    for ef in c.get('envFrom', []):
        name = ef.get('secretRef', {}).get('name', '')
        if name:
            env_from.append(f'  container={c[\"name\"]}  secretRef=\033[32m{name}\033[0m')
    for e in c.get('env', []):
        skr = e.get('valueFrom', {}).get('secretKeyRef', {})
        if skr:
            key_refs.append(f'  container={c[\"name\"]}  envVar={e[\"name\"]}  secret=\033[32m{skr[\"name\"]}\033[0m  key=\033[32m{skr[\"key\"]}\033[0m')
if not env_from and not key_refs:
    print('  (no secret env references found)')
else:
    if env_from:
        print('  [envFrom / secretRef]')
        print('\n'.join(env_from))
    if key_refs:
        print('  [env / secretKeyRef]')
        print('\n'.join(key_refs))
" 2>/dev/null || true
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
