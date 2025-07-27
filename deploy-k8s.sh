#!/bin/bash

# Generic Kubernetes deployment script

set -e

echo "🚀 Deploying FastAPI Microservices to Kubernetes..."

ENVIRONMENT=${1:-dev}

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "qa" ]]; then
    echo "❌ Invalid environment. Use 'dev' or 'qa'"
    echo "Usage: $0 [dev|qa]"
    exit 1
fi

echo "📦 Deploying to $ENVIRONMENT environment..."

# Create namespace if it doesn't exist
echo "Creating namespace..."
kubectl create namespace $ENVIRONMENT --dry-run=client -o yaml | kubectl apply -f -

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/$ENVIRONMENT/

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n $ENVIRONMENT

echo "📊 Deployment Status:"
kubectl get pods -n $ENVIRONMENT
echo ""
kubectl get services -n $ENVIRONMENT
echo ""

if kubectl get ingress -n $ENVIRONMENT &> /dev/null; then
    echo "Ingress:"
    kubectl get ingress -n $ENVIRONMENT
    echo ""
fi

echo "✅ Deployment completed successfully!"
echo ""
echo "📖 Next steps:"
echo "1. Initialize databases:"
echo "   kubectl exec -n $ENVIRONMENT deployment/postgres -- psql -U user -d postgres -c \"CREATE DATABASE orders_db;\""
echo "   kubectl exec -n $ENVIRONMENT deployment/postgres -- psql -U user -d postgres -c \"CREATE DATABASE sales_db;\""
echo ""
echo "2. Access services:"
echo "   kubectl port-forward -n $ENVIRONMENT service/orders-service 8001:8001"
echo "   kubectl port-forward -n $ENVIRONMENT service/sales-service 8002:8002"
echo ""
echo "3. Test endpoints:"
echo "   curl http://localhost:8001/health"
echo "   curl http://localhost:8002/health"
