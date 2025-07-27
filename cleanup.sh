#!/bin/bash

# Cleanup script for FastAPI Microservices

set -e

echo "🧹 Cleaning up deployments..."

ENVIRONMENT=${1:-both}

case $ENVIRONMENT in
    "dev")
        echo "🗑️  Removing DEV environment..."
        kubectl delete namespace dev --ignore-not-found=true
        ;;
    "qa")
        echo "🗑️  Removing QA environment..."
        kubectl delete namespace qa --ignore-not-found=true
        ;;
    "both")
        echo "🗑️  Removing both DEV and QA environments..."
        kubectl delete namespace dev --ignore-not-found=true
        kubectl delete namespace qa --ignore-not-found=true
        ;;
    *)
        echo "❌ Invalid environment. Use: dev, qa, or both"
        exit 1
        ;;
esac

echo "✅ Cleanup completed!"

# Optionally clean up Docker images
read -p "Do you want to clean up Docker images as well? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing Docker images..."
    eval $(minikube docker-env)
    docker rmi orders-service:latest orders-service:qa sales-service:latest sales-service:qa --force 2>/dev/null || true
    echo "✅ Docker images cleaned up!"
fi
