#!/bin/bash

set -e

# Set your image names and tags here (must exist in Docker Hub)
IMAGE_REGISTRY="docker.io/talko32"
FRONTEND_IMAGE="frontend"
FRONTEND_TAG="0.1.0.41"
BACKEND_IMAGE="backend"
BACKEND_TAG="0.1.0.41"
AUTH_IMAGE="store-auth"
AUTH_TAG="0.1.0.34"
JWT_SECRET="t2323"
NAMESPACE="prod"
IMAGE_PULL_POLICY="Always"

# Optional: Use minikube's Docker daemon if needed
# eval $(minikube docker-env)

helm upgrade --install jewelry-store . \
  --namespace $NAMESPACE --create-namespace \
  --set image.registry=$IMAGE_REGISTRY \
  --set frontend.image.name=$FRONTEND_IMAGE \
  --set image.frontendTag=$FRONTEND_TAG \
  --set backend.image.name=$BACKEND_IMAGE \
  --set image.backendTag=$BACKEND_TAG \
  --set authService.image.name=$AUTH_IMAGE \
  --set image.authTag=$AUTH_TAG \
  --set image.pullPolicy=$IMAGE_PULL_POLICY \
  --set jwtSecret=$JWT_SECRET

echo "\nDeployed! Resources in namespace $NAMESPACE:"
kubectl get all -n $NAMESPACE
