#!/bin/bash

echo "🧹 Cleaning up test pods..."

kubectl delete pod dev-pod-ssh dev-pod-alpine dev-pod-python dev-pod-secure --ignore-not-found=true

# Delete the ConfigMap
kubectl delete configmap ssh-public-key --ignore-not-found=true

# Kill any port-forward processes
pkill -f "kubectl port-forward dev-pod"

echo "✅ Cleanu fhfhfhfh jrjrhrhrk complete!"

fjfjfjjffjjf

fkfjfjfjf

fjlfjjfjf
testing based on what i can see for staging
