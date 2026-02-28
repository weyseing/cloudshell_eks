#!/bin/bash
set -e

# get args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help) echo "Usage: $0 [--namespace <name>]"; exit 0 ;;
    --namespace) NAMESPACE="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done


# fetch namespaces from current cluster
echo "Fetching namespaces..."
NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

if [[ -z "$NAMESPACES" ]]; then
  echo "Error: no namespaces found. Is the cluster set? Run eks_set_cluster.sh first."
  exit 1
fi

# if namespace not provided via arg
if [[ -z "$NAMESPACE" ]]; then
  if [ -t 0 ]; then
    # interactive: show select menu
    echo ""
    PS3="Select namespace: "
    select NAMESPACE in $NAMESPACES; do
      if [[ -n "$NAMESPACE" ]]; then
        break
      else
        echo "Invalid selection, try again."
      fi
    done
  else
    # non-interactive: list and exit
    echo ""
    echo "Available namespaces:"
    for ns in $NAMESPACES; do echo "  $ns"; done
    echo ""
    echo "Re-run with: ./eks_set_namespace.sh --namespace <name>"
    exit 1
  fi
fi

# Export to environment variable for current session
export EKS_NAMESPACE="$NAMESPACE"

echo "Namespace set to: $NAMESPACE (EKS_NAMESPACE=$NAMESPACE)"
echo "This setting is active in the current shell session only."