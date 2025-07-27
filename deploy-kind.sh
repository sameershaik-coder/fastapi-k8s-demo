#!/bin/bash

# Kind deployment script for FastAPI microservices

set -e

echo "🚀 Starting Kind deployment for FastAPI Microservices..."

# Configuration
CLUSTER_NAME="fastapi-microservices"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

# Check if Kind is installed
if ! command -v kind &> /dev/null; then
    echo "❌ Kind is not installed. Please install Kind first:"
    echo "   # On Linux/macOS:"
    echo "   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
    echo "   chmod +x ./kind"
    echo "   sudo mv ./kind /usr/local/bin/kind"
    echo ""
    echo "   # Or with package managers:"
    echo "   # brew install kind          (macOS)"
    echo "   # choco install kind         (Windows)"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Function to create local registry
create_registry() {
    # Create registry container unless it already exists
    if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" != 'true' ]; then
        echo "🏗️  Creating local Docker registry..."
        docker run \
            -d --restart=always -p "127.0.0.1:${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" \
            registry:2
    else
        echo "📦 Local Docker registry already running"
    fi
}

# Function to connect registry to Kind network
connect_registry() {
    if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}" 2>/dev/null)" = 'null' ]; then
        echo "🔗 Connecting registry to Kind network..."
        docker network connect "kind" "${REGISTRY_NAME}"
    fi
}

# Function to create Kind cluster
create_cluster() {
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        echo "🔄 Kind cluster '${CLUSTER_NAME}' already exists"
        kubectl cluster-info --context kind-${CLUSTER_NAME}
    else
        echo "🆕 Creating Kind cluster..."
        kind create cluster --config=kind-config.yaml --name=${CLUSTER_NAME}
        
        # Connect registry to cluster network
        connect_registry
        
        # Configure cluster to use local registry
        echo "⚙️  Configuring cluster to use local registry..."
        kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
    fi
}

# Function to install NGINX Ingress Controller
install_ingress() {
    echo "🌐 Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    echo "⏳ Waiting for Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
}

# Function to build and load Docker images
build_and_load_images() {
    echo "🏗️  Building Docker images..."
    
    # Build orders service
    echo "Building orders-service..."
    docker build -t orders-service:latest ./services/orders/
    kind load docker-image orders-service:latest --name=${CLUSTER_NAME}
    
    # Build sales service  
    echo "Building sales-service..."
    docker build -t sales-service:latest ./services/sales/
    kind load docker-image sales-service:latest --name=${CLUSTER_NAME}
    
    echo "✅ Images built and loaded into Kind cluster"
}

# Function to deploy applications
deploy_applications() {
    echo "📦 Deploying applications..."
    
    # Deploy all Kind-specific manifests
    kubectl apply -f k8s/kind/
    
    echo "⏳ Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment --all -n dev
    
    echo "📊 Deployment Status:"
    kubectl get pods -n dev
    echo ""
    kubectl get services -n dev
    echo ""
    kubectl get ingress -n dev
}

# Function to initialize databases
init_databases() {
    echo "🗄️  Initializing databases..."
    
    # Wait for PostgreSQL to be ready
    echo "⏳ Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n dev --timeout=120s
    
    # Create databases
    echo "Creating orders_db..."
    kubectl exec -n dev deployment/postgres -- psql -U user -d postgres -c "CREATE DATABASE orders_db;" 2>/dev/null || echo "Database orders_db already exists"
    
    echo "Creating sales_db..."
    kubectl exec -n dev deployment/postgres -- psql -U user -d postgres -c "CREATE DATABASE sales_db;" 2>/dev/null || echo "Database sales_db already exists"
    
    echo "✅ Databases initialized"
}

# Function to setup local hosts
setup_hosts() {
    echo "🔧 Setting up local hosts..."
    
    # Check if entries already exist
    if grep -q "dev.microservices.local" /etc/hosts; then
        echo "Host entries already exist in /etc/hosts"
    else
        echo "Adding host entries to /etc/hosts (requires sudo)..."
        echo "127.0.0.1 dev.microservices.local" | sudo tee -a /etc/hosts
        echo "✅ Host entries added"
    fi
}

# Function to display access information
show_access_info() {
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo ""
    echo "📖 Access Information:"
    echo "  Cluster: kind-${CLUSTER_NAME}"
    echo "  Context: kind-${CLUSTER_NAME}"
    echo ""
    echo "🌐 Service URLs (via Ingress):"
    echo "  Orders API:  http://dev.microservices.local/orders"
    echo "  Sales API:   http://dev.microservices.local/sales"
    echo ""
    echo "🧪 Quick Test Commands:"
    echo "  curl http://dev.microservices.local/orders/health"
    echo "  curl http://dev.microservices.local/sales/health"
    echo ""
    echo "📋 Useful Commands:"
    echo "  kubectl get pods -n dev"
    echo "  kubectl logs -f deployment/orders-service -n dev"
    echo "  kubectl logs -f deployment/sales-service -n dev"
    echo ""
    echo "🧹 Cleanup:"
    echo "  kind delete cluster --name=${CLUSTER_NAME}"
    echo "  docker rm -f ${REGISTRY_NAME}"
}

# Main execution
main() {
    create_registry
    create_cluster
    install_ingress
    build_and_load_images
    deploy_applications
    init_databases
    setup_hosts
    show_access_info
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy"|"")
        main
        ;;
    "cleanup"|"clean")
        echo "🧹 Cleaning up Kind cluster and registry..."
        kind delete cluster --name=${CLUSTER_NAME} || true
        docker rm -f ${REGISTRY_NAME} || true
        echo "✅ Cleanup completed"
        ;;
    "status")
        echo "📊 Kind Cluster Status:"
        kind get clusters
        echo ""
        if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
            kubectl cluster-info --context kind-${CLUSTER_NAME}
            echo ""
            kubectl get pods -n dev 2>/dev/null || echo "No dev namespace found"
        fi
        ;;
    *)
        echo "Usage: $0 [deploy|cleanup|status]"
        echo "  deploy  - Deploy the full stack (default)"
        echo "  cleanup - Remove Kind cluster and registry"
        echo "  status  - Show cluster status"
        exit 1
        ;;
esac
