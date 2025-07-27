#!/bin/bash

# Build and Deploy FastAPI Microservices to Minikube

set -e

echo "🚀 Starting deployment to Minikube..."

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "❌ Minikube is not running. Please start minikube first with: minikube start"
    exit 1
fi

# Set Docker environment to use minikube's Docker daemon
echo "🔧 Setting up Docker environment..."
eval $(minikube docker-env)

# Build Docker images
echo "🏗️  Building Docker images..."
echo "Building Orders Service..."
docker build -t orders-service:latest ./services/orders/
docker build -t orders-service:qa ./services/orders/

echo "Building Sales Service..."
docker build -t sales-service:latest ./services/sales/
docker build -t sales-service:qa ./services/sales/

echo "✅ Docker images built successfully!"

# Deploy to environments based on argument
ENVIRONMENT=${1:-dev}

case $ENVIRONMENT in
    "dev")
        echo "🌱 Deploying to DEV environment..."
        kubectl apply -f k8s/dev/
        ;;
    "qa")
        echo "🧪 Deploying to QA environment..."
        kubectl apply -f k8s/qa/
        ;;
    "both")
        echo "🌱 Deploying to DEV environment..."
        kubectl apply -f k8s/dev/
        echo "🧪 Deploying to QA environment..."
        kubectl apply -f k8s/qa/
        ;;
    *)
        echo "❌ Invalid environment. Use: dev, qa, or both"
        exit 1
        ;;
esac

echo "⏳ Waiting for deployments to be ready..."
sleep 10

# Check deployment status
echo "📊 Checking deployment status..."
if [ "$ENVIRONMENT" = "dev" ] || [ "$ENVIRONMENT" = "both" ]; then
    echo "DEV Environment:"
    kubectl get pods -n dev
    echo ""
fi

if [ "$ENVIRONMENT" = "qa" ] || [ "$ENVIRONMENT" = "both" ]; then
    echo "QA Environment:"
    kubectl get pods -n qa
    echo ""
fi

# Get service URLs
echo "🌐 Service URLs:"
MINIKUBE_IP=$(minikube ip)

if [ "$ENVIRONMENT" = "dev" ] || [ "$ENVIRONMENT" = "both" ]; then
    echo "DEV Environment:"
    echo "  Orders Service: http://$MINIKUBE_IP:30001"
    echo "  Sales Service:  http://$MINIKUBE_IP:30002"
    echo ""
fi

if [ "$ENVIRONMENT" = "qa" ] || [ "$ENVIRONMENT" = "both" ]; then
    echo "QA Environment:"
    echo "  Orders Service: http://$MINIKUBE_IP:31001"
    echo "  Sales Service:  http://$MINIKUBE_IP:31002"
    echo ""
fi

echo "✅ Deployment completed successfully!"
echo ""
echo "📖 Quick commands:"
echo "  - View all pods: kubectl get pods --all-namespaces"
echo "  - View logs: kubectl logs -f deployment/orders-service -n dev"
echo "  - Delete deployment: kubectl delete -f k8s/$ENVIRONMENT/"
