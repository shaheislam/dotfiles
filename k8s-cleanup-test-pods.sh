#!/bin/bash

echo "🧹 Cleaning up test pods..."

# Delete the pods
kubectl delete pod dev-pod-ssh dev-pod-alpine dev-pod-python dev-pod-secure --ignore-not-found=true

# Delete the ConfigMap
kubectl delete configmap ssh-public-key --ignore-not-found=true

# Kill any port-forward processes
pkill -f "kubectl port-forward dev-pod"

echo "✅ Cleanup complete!"