#!/bin/bash

# Test script for Kind deployment

set -e

echo "🧪 Testing FastAPI Microservices on Kind..."

CLUSTER_NAME="fastapi-microservices"

# Check if Kind cluster is running
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "❌ Kind cluster '${CLUSTER_NAME}' is not running."
    echo "Run './deploy-kind.sh' first to create the cluster."
    exit 1
fi

# Check if kubectl context is set correctly
if ! kubectl config current-context | grep -q "kind-${CLUSTER_NAME}"; then
    echo "🔧 Setting kubectl context to Kind cluster..."
    kubectl config use-context kind-${CLUSTER_NAME}
fi

# Check if dev namespace exists and pods are running
echo "📊 Checking cluster status..."
if ! kubectl get namespace dev &> /dev/null; then
    echo "❌ Dev namespace not found. Please run deployment first."
    exit 1
fi

echo "Pods in dev namespace:"
kubectl get pods -n dev

# Check if all pods are ready
if ! kubectl wait --for=condition=ready pod --all -n dev --timeout=60s; then
    echo "❌ Some pods are not ready. Check the deployment."
    kubectl get pods -n dev
    exit 1
fi

# Test function for ingress endpoints
test_ingress_endpoint() {
    local path=$1
    local expected_status=$2
    local description=$3
    
    echo -n "Testing $description... "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
        "http://dev.microservices.local${path}" || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        echo "✅ PASSED"
        if [ -f /tmp/response.json ]; then
            echo "  Response: $(cat /tmp/response.json)"
        fi
    else
        echo "❌ FAILED (HTTP $response)"
        if [ -f /tmp/response.json ]; then
            echo "  Response: $(cat /tmp/response.json)"
        fi
        # Try to get more info about the ingress
        echo "  Ingress status:"
        kubectl get ingress -n dev
    fi
    echo ""
}

# Test POST function for ingress endpoints
test_ingress_post() {
    local path=$1
    local data=$2
    local description=$3
    
    echo -n "Testing $description... "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
        -X POST "http://dev.microservices.local${path}" \
        -H "Content-Type: application/json" \
        -d "$data" || echo "000")
    
    if [ "$response" = "200" ]; then
        echo "✅ PASSED"
        echo "  Response: $(cat /tmp/response.json)"
    else
        echo "❌ FAILED (HTTP $response)"
        if [ -f /tmp/response.json ]; then
            echo "  Response: $(cat /tmp/response.json)"
        fi
    fi
    echo ""
}

# Test function for port-forward endpoints (fallback)
test_portforward_endpoint() {
    local service=$1
    local port=$2
    local path=$3
    local expected_status=$4
    local description=$5
    
    echo -n "Testing $description (via port-forward)... "
    
    # Start port-forward in background
    kubectl port-forward -n dev service/${service} ${port}:${port} &
    PF_PID=$!
    sleep 2
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
        "http://localhost:${port}${path}" || echo "000")
    
    # Kill port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
    
    if [ "$response" = "$expected_status" ]; then
        echo "✅ PASSED"
        if [ -f /tmp/response.json ]; then
            echo "  Response: $(cat /tmp/response.json)"
        fi
    else
        echo "❌ FAILED (HTTP $response)"
        if [ -f /tmp/response.json ]; then
            echo "  Response: $(cat /tmp/response.json)"
        fi
    fi
    echo ""
}

echo "=== Testing Ingress Endpoints ==="

# Test Orders Service via Ingress
test_ingress_endpoint "/orders/" "200" "Orders service root via Ingress"
test_ingress_endpoint "/orders/health" "200" "Orders service health via Ingress"
test_ingress_endpoint "/orders/orders" "200" "Get orders list via Ingress"

# Test creating an order via Ingress
test_ingress_post "/orders/orders" '{
    "customer_name": "Test Customer",
    "product_name": "Test Product",
    "quantity": 2,
    "price": 99.99
}' "Create order via Ingress"

# Test Sales Service via Ingress
test_ingress_endpoint "/sales/" "200" "Sales service root via Ingress"
test_ingress_endpoint "/sales/health" "200" "Sales service health via Ingress"
test_ingress_endpoint "/sales/sales" "200" "Get sales list via Ingress"

# Test creating a sale via Ingress
test_ingress_post "/sales/sales" '{
    "salesperson_name": "Test Salesperson",
    "customer_name": "Test Customer",
    "product_name": "Test Product",
    "quantity": 1,
    "unit_price": 199.99,
    "commission_rate": 0.05
}' "Create sale via Ingress"

echo "=== Fallback: Testing via Port-Forward ==="

# If ingress tests failed, try port-forward as fallback
test_portforward_endpoint "orders-service" "8001" "/health" "200" "Orders service health"
test_portforward_endpoint "sales-service" "8002" "/health" "200" "Sales service health"

# Clean up
rm -f /tmp/response.json

echo "🎉 Testing completed!"
echo ""
echo "📊 Cluster Information:"
kubectl get pods -n dev
echo ""
kubectl get services -n dev
echo ""
kubectl get ingress -n dev
echo ""
echo "📖 Access URLs:"
echo "  Orders API: http://dev.microservices.local/orders"
echo "  Sales API:  http://dev.microservices.local/sales"
echo ""
echo "🔧 Useful Commands:"
echo "  kubectl logs -f deployment/orders-service -n dev"
echo "  kubectl logs -f deployment/sales-service -n dev"
echo "  kubectl port-forward -n dev service/orders-service 8001:8001"
echo "  kubectl port-forward -n dev service/sales-service 8002:8002"
