#!/bin/bash

# Build and Deploy FastAPI Microservices to Minikube with Ingress

set -e

echo "🚀 Starting deployment to Minikube..."

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "❌ Minikube is not running. Please start minikube first with: minikube start"
    exit 1
fi

# Enable Ingress addon
echo "🔌 Enabling Ingress addon..."
minikube addons enable ingress

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
sleep 15

# Wait for Ingress controller to be ready
echo "⏳ Waiting for Ingress controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

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

# Get Ingress information
echo "🌐 Ingress Information:"
MINIKUBE_IP=$(minikube ip)

if [ "$ENVIRONMENT" = "dev" ] || [ "$ENVIRONMENT" = "both" ]; then
    echo "DEV Environment:"
    echo "  Ingress URL: http://$MINIKUBE_IP"
    echo "  Orders API:  http://$MINIKUBE_IP/orders"
    echo "  Sales API:   http://$MINIKUBE_IP/sales"
    echo "  Host Header: dev.microservices.local"
    echo ""
fi

if [ "$ENVIRONMENT" = "qa" ] || [ "$ENVIRONMENT" = "both" ]; then
    echo "QA Environment:"
    echo "  Ingress URL: http://$MINIKUBE_IP"
    echo "  Orders API:  http://$MINIKUBE_IP/orders"
    echo "  Sales API:   http://$MINIKUBE_IP/sales"
    echo "  API v1 Orders: http://$MINIKUBE_IP/api/v1/orders"
    echo "  API v1 Sales:  http://$MINIKUBE_IP/api/v1/sales"
    echo "  Host Header: qa.microservices.local"
    echo ""
fi

echo "✅ Deployment completed successfully!"
echo ""
echo "📖 Quick commands:"
echo "  - View all pods: kubectl get pods --all-namespaces"
echo "  - View ingress: kubectl get ingress --all-namespaces"
echo "  - View logs: kubectl logs -f deployment/orders-service -n dev"
echo "  - Delete deployment: kubectl delete -f k8s/$ENVIRONMENT/"
echo ""
echo "🔧 To add host entries (optional):"
echo "  echo '$MINIKUBE_IP dev.microservices.local' | sudo tee -a /etc/hosts"
echo "  echo '$MINIKUBE_IP qa.microservices.local' | sudo tee -a /etc/hosts"
