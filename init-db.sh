#!/bin/bash

# Database initialization script

set -e

echo "🗄️  Initializing databases..."

# Function to create database if it doesn't exist
create_database() {
    local db_name=$1
    local namespace=$2
    local pod_name=$(kubectl get pods -n $namespace -l app=postgres -o jsonpath='{.items[0].metadata.name}')
    
    echo "Creating database: $db_name in namespace: $namespace"
    
    if [ "$namespace" = "dev" ]; then
        kubectl exec -n $namespace $pod_name -- psql -U user -d postgres -c "CREATE DATABASE $db_name;" 2>/dev/null || echo "Database $db_name already exists"
    else
        kubectl exec -n $namespace $pod_name -- psql -U qauser -d postgres -c "CREATE DATABASE $db_name;" 2>/dev/null || echo "Database $db_name already exists"
    fi
}

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL pods to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n dev --timeout=120s 2>/dev/null || echo "Dev PostgreSQL not found"
kubectl wait --for=condition=ready pod -l app=postgres -n qa --timeout=120s 2>/dev/null || echo "QA PostgreSQL not found"

# Create databases for dev environment
if kubectl get namespace dev &> /dev/null; then
    echo "🌱 Setting up DEV databases..."
    create_database "orders_db" "dev"
    create_database "sales_db" "dev"
fi

# Create databases for qa environment
if kubectl get namespace qa &> /dev/null; then
    echo "🧪 Setting up QA databases..."
    create_database "orders_db" "qa"
    create_database "sales_db" "qa"
fi

echo "✅ Database initialization completed!"
