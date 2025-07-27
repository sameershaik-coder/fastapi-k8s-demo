#!/bin/bash

# Simple test script for Docker Compose deployment

set -e

echo "🧪 Testing FastAPI Microservices with Docker Compose..."

# Check if Docker Compose is running
if ! docker-compose ps | grep -q "Up"; then
    echo "⚠️  Services are not running. Starting them first..."
    docker-compose up -d
    echo "⏳ Waiting for services to start..."
    sleep 10
fi

# Test function
test_endpoint() {
    local url=$1
    local expected_status=$2
    local description=$3
    
    echo -n "Testing $description... "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json "$url" || echo "000")
    
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
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
        -X POST "$url" \
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

ORDERS_URL="http://localhost:8001"
SALES_URL="http://localhost:8002"

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

# Clean up
rm -f /tmp/response.json

echo "🎉 Testing completed!"
echo ""
echo "To view the created data:"
echo "  Orders: curl $ORDERS_URL/orders"
echo "  Sales:  curl $SALES_URL/sales"
echo ""
echo "To stop services: docker-compose down"
