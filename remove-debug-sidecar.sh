#!/bin/bash

# Safe Debug Sidecar Removal Script
# Removes debug-sidecar container and diagnostics volume by name, not index

set -e

DEPLOYMENT_NAME="${1}"
NAMESPACE="${2:-default}"

if [ -z "$DEPLOYMENT_NAME" ]; then
  echo "Usage: $0 <deployment-name> [namespace]"
  echo "Example: $0 my-app-deployment production"
  exit 1
fi

echo "🔍 Checking deployment: $DEPLOYMENT_NAME in namespace: $NAMESPACE"

# Check if deployment exists
if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Deployment '$DEPLOYMENT_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

echo "✅ Deployment found"

# Find debug-sidecar container index
echo "🔍 Looking for debug-sidecar container..."
CONTAINER_INDEX=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[*]}{@.name}{"\n"}{end}' | grep -n "debug-sidecar" | cut -d: -f1)

if [ -z "$CONTAINER_INDEX" ]; then
  echo "❌ debug-sidecar container not found in deployment $DEPLOYMENT_NAME"
  echo "Available containers:"
  kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[*]}{@.name}{"\n"}{end}' | sed 's/^/  - /'
  exit 1
fi

CONTAINER_INDEX=$((CONTAINER_INDEX-1))  # Convert to 0-based index
echo "✅ Found debug-sidecar container at index: $CONTAINER_INDEX"

# Check debug-sidecar labels to determine what we need to clean up
echo "🔍 Checking debug-sidecar configuration..."
DEBUG_SIDECAR_ADDED=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.debug-sidecar\.dotdebug/added}' 2>/dev/null || echo "")
PROCESS_NAMESPACE_SHARING=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.debug-sidecar\.dotdebug/process-namespace-sharing}' 2>/dev/null || echo "")

if [ "$DEBUG_SIDECAR_ADDED" != "true" ]; then
  echo "⚠️  This debug-sidecar was not added by our script (no tracking labels found)"
  echo "   Proceeding with removal but cannot clean up process namespace sharing automatically"
  PROCESS_NAMESPACE_SHARING="unknown"
fi

if [ "$PROCESS_NAMESPACE_SHARING" = "true" ]; then
  echo "✅ Process namespace sharing was enabled by our script - will remove it"
elif [ "$PROCESS_NAMESPACE_SHARING" = "false" ]; then
  echo "✅ Process namespace sharing was not enabled - will skip removal"
else
  echo "⚠️  Cannot determine if process namespace sharing was enabled by our script"
fi

# Find diagnostics volume index
echo "🔍 Looking for diagnostics volume..."
VOLUME_INDEX=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.volumes[*]}{@.name}{"\n"}{end}' | grep -n "diagnostics" | cut -d: -f1)

if [ -n "$VOLUME_INDEX" ]; then
  VOLUME_INDEX=$((VOLUME_INDEX-1))  # Convert to 0-based index
  echo "✅ Found diagnostics volume at index: $VOLUME_INDEX"
else
  echo "⚠️  diagnostics volume not found (this is okay if not using shared volume)"
fi

# Confirm removal
echo ""
echo "📋 About to remove:"
if [ "$PROCESS_NAMESPACE_SHARING" = "true" ]; then
  echo "  🔓 Process namespace sharing (shareProcessNamespace: true)"
fi
echo "  - Container: debug-sidecar (index $CONTAINER_INDEX)"
if [ -n "$VOLUME_INDEX" ]; then
  echo "  - Volume: diagnostics (index $VOLUME_INDEX)"
fi
if [ "$DEBUG_SIDECAR_ADDED" = "true" ]; then
  echo "  - Debug-sidecar tracking labels"
fi
echo "  - From deployment: $DEPLOYMENT_NAME"
echo "  - In namespace: $NAMESPACE"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Cancelled"
  exit 1
fi

# Remove process namespace sharing if we added it
if [ "$PROCESS_NAMESPACE_SHARING" = "true" ]; then
  echo "🗑️  Removing process namespace sharing..."
  kubectl patch deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/shareProcessNamespace"}]'
  echo "✅ Process namespace sharing removed"
fi

# Remove container
echo "🗑️  Removing debug-sidecar container..."
kubectl patch deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"remove\", \"path\": \"/spec/template/spec/containers/${CONTAINER_INDEX}\"}]"
echo "✅ Container removed"

# Remove debug-sidecar labels if we added them
if [ "$DEBUG_SIDECAR_ADDED" = "true" ]; then
  echo "🗑️  Removing debug-sidecar tracking labels..."
  kubectl label deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
    'debug-sidecar.dotdebug/added-' \
    'debug-sidecar.dotdebug/process-namespace-sharing-' \
    'debug-sidecar.dotdebug/version-' \
    2>/dev/null || true
  echo "✅ Labels removed"
fi

echo ""
echo "🎉 Debug sidecar removed successfully!"
echo "📊 Deployment will automatically roll out new pods without the debug sidecar"
echo ""
echo "Monitor rollout with:"
echo "  kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE"
