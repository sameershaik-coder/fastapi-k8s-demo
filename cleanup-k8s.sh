#!/bin/bash

# Cleanup script for Kubernetes deployments

set -e

echo "🧹 Cleaning up Kubernetes deployments..."

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
        echo "Usage: $0 [dev|qa|both]"
        exit 1
        ;;
esac

echo "✅ Cleanup completed!"
