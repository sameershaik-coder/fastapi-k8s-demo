#!/bin/bash

# Kind deployment script for FastAPI microservices

set -e

# Configuration
CLUSTER_NAME="fastapi-microservices"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

# Parse command line arguments first
ACTION="${1:-deploy}"

echo "🚀 Starting Kind deployment for FastAPI Microservices..."

# For cleanup operations, we don't need to check all dependencies
if [[ "$ACTION" == "cleanup" || "$ACTION" == "clean" || "$ACTION" == "cleanup-hosts" || "$ACTION" == "help" || "$ACTION" == "--help" || "$ACTION" == "-h" ]]; then
    # Skip dependency checks for cleanup and help
    :
else
    # Check dependencies for deploy and status operations
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
    
    # First, create the namespace
    echo "Creating namespace..."
    kubectl apply -f k8s/dev/00-namespace.yaml
    
    # Wait a moment for namespace to be ready
    sleep 2
    
    # Using external PostgreSQL database on WSL2
    echo "📊 Using external PostgreSQL database on WSL2..."
    
    # Test database connectivity before deploying apps
    echo "🔍 Testing database connectivity..."
    if command -v psql >/dev/null 2>&1; then
        if psql "postgresql://k8s_user:k8s_password@localhost:5432/orders_db" -c "SELECT 1;" >/dev/null 2>&1; then
            echo "✅ Orders database connectivity verified"
        else
            echo "⚠️  Warning: Cannot connect to orders_db. Please check PostgreSQL setup."
        fi
        
        if psql "postgresql://k8s_user:k8s_password@localhost:5432/sales_db" -c "SELECT 1;" >/dev/null 2>&1; then
            echo "✅ Sales database connectivity verified"
        else
            echo "⚠️  Warning: Cannot connect to sales_db. Please check PostgreSQL setup."
        fi
    else
        echo "⚠️  psql not found, skipping connectivity test"
    fi
    
    # Deploy applications (they will connect to external database)
    echo "🚀 Deploying FastAPI services..."
    kubectl apply -f k8s/dev/orders-service.yaml
    kubectl apply -f k8s/dev/sales-service.yaml
    
    # Deploy ingress last
    echo "Deploying Ingress..."
    kubectl apply -f k8s/dev/ingress.yaml
    
    echo "⏳ Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment --all -n dev
    
    echo "📊 Deployment Status:"
    kubectl get pods -n dev
    echo ""
    kubectl get services -n dev
    echo ""
    kubectl get ingress -n dev
}

# Database initialization functions removed - using external PostgreSQL on WSL2
# The external PostgreSQL server should have the following databases pre-configured:
# - orders_db (owner: k8s_user)
# - sales_db (owner: k8s_user)
# Database connection: postgresql://k8s_user:k8s_password@host.docker.internal:5432/

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

# Function to cleanup local hosts
cleanup_hosts() {
    echo "🧹 Cleaning up local hosts..."
    
    if grep -q "dev.microservices.local" /etc/hosts; then
        echo "Removing host entries from /etc/hosts (requires sudo)..."
        sudo sed -i '/127\.0\.0\.1[[:space:]]*dev\.microservices\.local/d' /etc/hosts
        echo "✅ Host entries removed"
    else
        echo "No host entries found in /etc/hosts"
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
    echo "🗄️  Database Information:"
    echo "  External PostgreSQL on WSL2"
    echo "  Connection: postgresql://k8s_user:k8s_password@host.docker.internal:5432/"
    echo "  Databases: orders_db, sales_db"
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
    setup_hosts
    show_access_info
}

# Parse command line arguments
case "$ACTION" in
    "deploy"|"")
        main
        ;;
    "cleanup"|"clean")
        echo "🧹 Cleaning up Kind cluster and registry..."
        
        # Delete Kind cluster (this also removes kubectl context)
        if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
            echo "Deleting Kind cluster: ${CLUSTER_NAME}"
            kind delete cluster --name=${CLUSTER_NAME}
        else
            echo "Kind cluster ${CLUSTER_NAME} not found, skipping..."
        fi
        
        # Remove local Docker registry
        if docker ps -a --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
            echo "Removing Docker registry: ${REGISTRY_NAME}"
            docker rm -f ${REGISTRY_NAME}
        else
            echo "Docker registry ${REGISTRY_NAME} not found, skipping..."
        fi
        
        # Clean up host entries
        cleanup_hosts
        
        # Clean up any dangling images (optional)
        echo "Cleaning up Kind-related Docker images..."
        docker image prune -f --filter label=io.x-k8s.kind.cluster=${CLUSTER_NAME} || true
        
        echo "✅ Cleanup completed successfully"
        ;;
    "cleanup-hosts")
        cleanup_hosts
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
    "help"|"--help"|"-h")
        echo "Usage: $0 [deploy|cleanup|cleanup-hosts|status|help]"
        echo "  deploy        - Deploy the full stack (default)"
        echo "  cleanup       - Remove Kind cluster, registry, and host entries"
        echo "  cleanup-hosts - Remove only host entries from /etc/hosts"
        echo "  status        - Show cluster status"
        echo "  help          - Show this help message"
        exit 0
        ;;
    *)
        echo "Usage: $0 [deploy|cleanup|cleanup-hosts|status|help]"
        echo "  deploy        - Deploy the full stack (default)"
        echo "  cleanup       - Remove Kind cluster, registry, and host entries"
        echo "  cleanup-hosts - Remove only host entries from /etc/hosts"
        echo "  status        - Show cluster status"
        echo "  help          - Show this help message"
        exit 1
        ;;
esac
