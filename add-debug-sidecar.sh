#!/bin/bash

# Safe Debug Sidecar Addition Script
# Adds debug-sidecar container and diagnostics volume to existing deployment
# Optional: Enable process namespace sharing for enhanced .NET debugging

set -e

DEPLOYMENT_NAME=""
NAMESPACE="default"
SHARE_PROCESS_NAMESPACE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --share-process-namespace)
      SHARE_PROCESS_NAMESPACE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS] <deployment-name> [namespace]"
      echo ""
      echo "Options:"
      echo "  --share-process-namespace  Enable process namespace sharing for enhanced .NET debugging"
      echo "                            (Security: Allows sidecar to see processes from main app)"
      echo "  --help, -h                Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 my-app-deployment production                    # Secure volume-based debugging"
      echo "  $0 --share-process-namespace my-app production     # Enhanced process-level debugging"
      exit 0
      ;;
    *)
      if [ -z "$DEPLOYMENT_NAME" ]; then
        DEPLOYMENT_NAME="$1"
      elif [ "$NAMESPACE" = "default" ]; then
        NAMESPACE="$1"
      else
        echo "❌ Unknown argument: $1"
        echo "Use --help for usage information"
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$DEPLOYMENT_NAME" ]; then
  echo "Usage: $0 [OPTIONS] <deployment-name> [namespace]"
  echo "Use --help for more information"
  exit 1
fi

echo "🔍 Checking deployment: $DEPLOYMENT_NAME in namespace: $NAMESPACE"

# Check if deployment exists
if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Deployment '$DEPLOYMENT_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

echo "✅ Deployment found"

# Check if debug-sidecar already exists
echo "🔍 Checking for existing debug-sidecar..."
EXISTING_CONTAINER=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[*]}{@.name}{"\n"}{end}' | grep "debug-sidecar" || true)

if [ -n "$EXISTING_CONTAINER" ]; then
  echo "⚠️  debug-sidecar container already exists in deployment $DEPLOYMENT_NAME"
  echo "Remove it first with: ./remove-debug-sidecar.sh $DEPLOYMENT_NAME $NAMESPACE"
  exit 1
fi

echo "✅ No existing debug-sidecar found"

# Check if diagnostics volume already exists
echo "🔍 Checking for existing diagnostics volume..."
EXISTING_VOLUME=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.volumes[*]}{@.name}{"\n"}{end}' | grep "diagnostics" || true)

if [ -n "$EXISTING_VOLUME" ]; then
  echo "ℹ️  diagnostics volume already exists - will reuse it"
  ADD_VOLUME=false
else
  echo "✅ No existing diagnostics volume found - will create it"
  ADD_VOLUME=true
fi

# Show current containers
echo ""
echo "📋 Current containers in deployment:"
kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[*]}{@.name}{"\n"}{end}' | sed 's/^/  - /'

# Confirm addition
echo ""
echo "📋 About to add:"
if [ "$SHARE_PROCESS_NAMESPACE" = true ]; then
  echo "  🔓 Process namespace sharing (shareProcessNamespace: true)"
  echo "     - Enables .NET process monitoring from sidecar"
  echo "     - Security: Sidecar can see processes and env vars from main app"
fi
echo "  - Container: debug-sidecar (with network debugging capabilities)"
if [ "$ADD_VOLUME" = true ]; then
  echo "  - Volume: diagnostics (emptyDir for shared data)"
fi
echo "  - To deployment: $DEPLOYMENT_NAME"
echo "  - In namespace: $NAMESPACE"
echo ""
if [ "$SHARE_PROCESS_NAMESPACE" = true ]; then
  echo "⚠️  Security Note: Process namespace sharing allows cross-container process visibility"
  echo "   This enables enhanced .NET debugging but reduces container isolation."
  echo ""
fi
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Cancelled"
  exit 1
fi

# Create JSON patch for container
CONTAINER_PATCH='{
  "name": "debug-sidecar",
  "image": "ghcr.io/mortenduus/dotdebug:latest",
  "command": ["sleep", "infinity"],
  "volumeMounts": [
    {
      "name": "diagnostics",
      "mountPath": "/tmp"
    }
  ],
  "securityContext": {
    "capabilities": {
      "add": ["NET_ADMIN", "SYS_PTRACE", "NET_RAW"]
    }
  },
  "resources": {
    "limits": {
      "memory": "256Mi",
      "cpu": "200m"
    },
    "requests": {
      "memory": "128Mi",
      "cpu": "100m"
    }
  }
}'

# Add container
echo "🚀 Adding debug-sidecar container..."
kubectl patch deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/containers/-\", \"value\": $CONTAINER_PATCH}]"
echo "✅ Container added"

# Add process namespace sharing if requested
if [ "$SHARE_PROCESS_NAMESPACE" = true ]; then
  echo "🚀 Enabling process namespace sharing..."
  kubectl patch deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --type='json' -p='[{"op": "add", "path": "/spec/template/spec/shareProcessNamespace", "value": true}]'
  echo "✅ Process namespace sharing enabled"
  
  # Label the deployment to track that we added process namespace sharing
  echo "🏷️  Adding debug-sidecar tracking labels..."
  kubectl label deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
    debug-sidecar.dotdebug/added=true \
    debug-sidecar.dotdebug/process-namespace-sharing=true \
    debug-sidecar.dotdebug/version=v0.4 \
    --overwrite
  echo "✅ Labels added"
else
  # Label the deployment to track that we added debug-sidecar without process sharing
  echo "🏷️  Adding debug-sidecar tracking labels..."
  kubectl label deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
    debug-sidecar.dotdebug/added=true \
    debug-sidecar.dotdebug/process-namespace-sharing=false \
    debug-sidecar.dotdebug/version=v0.4 \
    --overwrite
  echo "✅ Labels added"
fi

# Add volume if needed
if [ "$ADD_VOLUME" = true ]; then
  echo "🚀 Adding diagnostics volume..."
  
  # Check if volumes array exists, if not create it
  VOLUMES_EXIST=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.volumes}' | grep -q '\[' && echo "true" || echo "false")
  
  if [ "$VOLUMES_EXIST" = "true" ]; then
    # Add to existing volumes array
    kubectl patch deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --type='json' -p='[{"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "diagnostics", "emptyDir": {}}}]'
  else
    # Create volumes array
    kubectl patch deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --type='json' -p='[{"op": "add", "path": "/spec/template/spec/volumes", "value": [{"name": "diagnostics", "emptyDir": {}}]}]'
  fi
  
  echo "✅ Volume added"
fi

echo ""
echo "🎉 Debug sidecar added successfully!"
if [ "$SHARE_PROCESS_NAMESPACE" = true ]; then
  echo "🔓 Enhanced debugging mode: Process namespace sharing enabled"
  echo "   - Can monitor .NET processes with dotnet-counters, dotnet-dump, etc."
  echo "   - Use aliases: dotnet-procs, monitor-dotnet, dump-dotnet"
else
  echo "🔒 Secure debugging mode: Volume-based diagnostics only"
  echo "   - Configure your .NET app to write diagnostic data to /tmp"
  echo "   - Use aliases: tmp-files, analyze-latest-dump, watch-diagnostic-files"
fi
echo "📊 Deployment will automatically roll out new pods with the debug sidecar"
echo ""
echo "Monitor rollout with:"
echo "  kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE"
echo ""
echo "Access the debug sidecar once pods are ready:"
echo "  kubectl exec -it deployment/$DEPLOYMENT_NAME -n $NAMESPACE -c debug-sidecar -- zsh"
echo ""
echo "Remove when done:"
echo "  ./remove-debug-sidecar.sh $DEPLOYMENT_NAME $NAMESPACE"
