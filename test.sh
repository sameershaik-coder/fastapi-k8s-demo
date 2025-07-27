#!/bin/bash

# Test script for FastAPI microservices

set -e

echo "🧪 Testing FastAPI Microservices..."

# Get Minikube IP or use localhost for Docker Compose
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    MINIKUBE_IP=$(minikube ip)
    
    # Check if Ingress is available
    if kubectl get ingress -n dev &> /dev/null; then
        BASE_URL="http://$MINIKUBE_IP"
        ORDERS_URL="$BASE_URL/orders"
        SALES_URL="$BASE_URL/sales"
        echo "Using Minikube with Ingress: $MINIKUBE_IP"
        echo "Testing with Host Header: dev.microservices.local"
        CURL_OPTS="-H 'Host: dev.microservices.local'"
    else
        # Fallback to NodePort
        ORDERS_URL="http://$MINIKUBE_IP:30001"
        SALES_URL="http://$MINIKUBE_IP:30002"
        echo "Using Minikube with NodePort: $MINIKUBE_IP"
        CURL_OPTS=""
    fi
else
    ORDERS_URL="http://localhost:8001"
    SALES_URL="http://localhost:8002"
    echo "Using localhost (Docker Compose)"
    CURL_OPTS=""
fi

# Test function
test_endpoint() {
    local url=$1
    local expected_status=$2
    local description=$3
    
    echo -n "Testing $description... "
    
    if [ -n "$CURL_OPTS" ]; then
        response=$(curl -s -w "%{http_code}" -o /tmp/response.json $CURL_OPTS "$url" || echo "000")
    else
        response=$(curl -s -w "%{http_code}" -o /tmp/response.json "$url" || echo "000")
    fi
    
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

# Test POST function
test_post() {
    local url=$1
    local data=$2
    local description=$3
    
    echo -n "Testing $description... "
    
    if [ -n "$CURL_OPTS" ]; then
        response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
            $CURL_OPTS \
            -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$data" || echo "000")
    else
        response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
            -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$data" || echo "000")
    fi
    
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

echo "=== Orders Service Tests ==="
test_endpoint "$ORDERS_URL/" "200" "Orders service root"
test_endpoint "$ORDERS_URL/health" "200" "Orders service health"
test_endpoint "$ORDERS_URL/orders" "200" "Get orders list"

# Test creating an order
test_post "$ORDERS_URL/orders" '{
    "customer_name": "Test Customer",
    "product_name": "Test Product",
    "quantity": 2,
    "price": 99.99
}' "Create order"

echo "=== Sales Service Tests ==="
test_endpoint "$SALES_URL/" "200" "Sales service root"
test_endpoint "$SALES_URL/health" "200" "Sales service health"
test_endpoint "$SALES_URL/sales" "200" "Get sales list"

# Test creating a sale
test_post "$SALES_URL/sales" '{
    "salesperson_name": "Test Salesperson",
    "customer_name": "Test Customer",
    "product_name": "Test Product",
    "quantity": 1,
    "unit_price": 199.99,
    "commission_rate": 0.05
}' "Create sale"

# Test Ingress routing if available
if [ -n "$CURL_OPTS" ]; then
    echo "=== Ingress Routing Tests ==="
    test_endpoint "$BASE_URL/" "200" "Root endpoint via Ingress"
    test_endpoint "$BASE_URL/orders/health" "200" "Orders health via Ingress"
    test_endpoint "$BASE_URL/sales/health" "200" "Sales health via Ingress"
fi

# Clean up
rm -f /tmp/response.json

echo "🎉 Testing completed!"
echo ""
echo "To view the created data:"
if [ -n "$CURL_OPTS" ]; then
    echo "  Orders: curl $CURL_OPTS $ORDERS_URL/orders"
    echo "  Sales:  curl $CURL_OPTS $SALES_URL/sales"
else
    echo "  Orders: curl $ORDERS_URL/orders"
    echo "  Sales:  curl $SALES_URL/sales"
fi
