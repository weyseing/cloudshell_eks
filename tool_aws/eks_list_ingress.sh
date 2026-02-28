#!/bin/bash
set -e

# List all Ingresses in the current namespace with their hostnames, paths,
# backend services, and load balancer addresses.
# Optionally filter by a specific ingress name for full details.
#
# Usage:
#   All ingresses:     ./eks_list_ingress.sh
#   Single ingress:    ./eks_list_ingress.sh --ingress <name>

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0 [--ingress <name>]"; exit 0 ;;
    --ingress) INGRESS="$2"; shift ;;
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

# ── single ingress: full detail ───────────────────────────────────────────────
if [[ -n "$INGRESS" ]]; then
  echo "=== Ingress: $INGRESS (namespace: $NAMESPACE) ==="
  echo ""

  kubectl get ingress "$INGRESS" --namespace "$NAMESPACE" -o json | python3 -c "
import sys, json

d = json.load(sys.stdin)
meta = d.get('metadata', {})
spec = d.get('spec', {})
status = d.get('status', {})

# Annotations
annotations = meta.get('annotations', {})
ingress_class = (
    spec.get('ingressClassName') or
    annotations.get('kubernetes.io/ingress.class') or
    annotations.get('alb.ingress.kubernetes.io/scheme') or
    '(not set)'
)
print(f'Name       : {meta[\"name\"]}')
print(f'Namespace  : {meta[\"namespace\"]}')
print(f'Class      : {ingress_class}')
print(f'Created    : {meta.get(\"creationTimestamp\", \"\")}')

# Load balancer addresses
lb_hosts = [
    i.get('hostname') or i.get('ip', '')
    for i in status.get('loadBalancer', {}).get('ingress', [])
]
print(f'LB Address : {\" | \".join(lb_hosts) if lb_hosts else \"(pending)\"}')

# TLS
tls_list = spec.get('tls', [])
if tls_list:
    print('')
    print('TLS:')
    for t in tls_list:
        hosts = ', '.join(t.get('hosts', []))
        secret = t.get('secretName', '(none)')
        print(f'  hosts={hosts}  secret={secret}')

# Rules
rules = spec.get('rules', [])
print('')
print('Rules:')
for rule in rules:
    host = rule.get('host', '*')
    print(f'  Host: {host}')
    http = rule.get('http', {})
    for path in http.get('paths', []):
        p = path.get('path', '/')
        pt = path.get('pathType', '')
        be = path.get('backend', {})
        svc = be.get('service', {})
        svc_name = svc.get('name', be.get('serviceName', ''))
        svc_port = svc.get('port', {}).get('number', be.get('servicePort', ''))
        print(f'    {p} ({pt}) -> {svc_name}:{svc_port}')

# Key annotations
if annotations:
    print('')
    print('Key annotations:')
    for k, v in sorted(annotations.items()):
        print(f'  {k}: {v}')
"
  exit 0
fi

# ── all ingresses: summary table ──────────────────────────────────────────────
echo "=== Ingresses in namespace: $NAMESPACE ==="
echo ""

if ! kubectl get ingresses --namespace "$NAMESPACE" --no-headers 2>/dev/null | grep -q .; then
  echo "No ingresses found in namespace: $NAMESPACE"
  exit 0
fi

kubectl get ingresses --namespace "$NAMESPACE" -o json | python3 -c "
import sys, json

data = json.load(sys.stdin)
items = data.get('items', [])

# header
print('{:<30} {:<20} {:<40} {:<50} {:<10}'.format('NAME', 'CLASS', 'HOSTS', 'ADDRESS', 'PORTS'))
print('-' * 155)

for d in items:
    meta = d.get('metadata', {})
    spec = d.get('spec', {})
    status = d.get('status', {})
    annotations = meta.get('annotations', {})

    name = meta.get('name', '')
    ingress_class = (
        spec.get('ingressClassName') or
        annotations.get('kubernetes.io/ingress.class') or
        '-'
    )

    hosts = list({
        rule.get('host', '*')
        for rule in spec.get('rules', [])
        if rule.get('host')
    })
    host_str = ', '.join(hosts) if hosts else '*'

    lb_addrs = [
        i.get('hostname') or i.get('ip', '')
        for i in status.get('loadBalancer', {}).get('ingress', [])
    ]
    addr_str = ', '.join(lb_addrs) if lb_addrs else '(pending)'

    ports = '80'
    if spec.get('tls'):
        ports = '80, 443'

    print(f'{name:<30} {ingress_class:<20} {host_str:<40} {addr_str:<50} {ports:<10}')
"

echo ""
echo "Tip: re-run with --ingress <name> to see full rules and annotations."
