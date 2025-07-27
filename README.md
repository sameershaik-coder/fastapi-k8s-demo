# FastAPI Microservices with Kubernetes

This project contains two microservices (Orders and Sales) built with FastAPI and PostgreSQL. It can be deployed locally using Docker Compose or on any Kubernetes cluster.

## Architecture

- **Orders Service**: Manages order operations
- **Sales Service**: Manages sales operations
- **PostgreSQL**: Database for both services
- **Docker Compose**: Local development environment
- **Kubernetes**: Container orchestration for production deployments

## Project Structure

```
fastapi-k8s-demo/
├── services/
│   ├── orders/
│   │   ├── app/
│   │   │   └── main.py           # Orders FastAPI application
│   │   ├── Dockerfile            # Orders service Docker image
│   │   └── requirements.txt      # Python dependencies
│   └── sales/
│       ├── app/
│       │   └── main.py           # Sales FastAPI application
│       ├── Dockerfile            # Sales service Docker image
│       └── requirements.txt      # Python dependencies
├── k8s/
│   ├── dev/                      # Development environment
│   │   ├── postgres.yaml         # PostgreSQL deployment
│   │   ├── orders-service.yaml   # Orders service deployment
│   │   ├── sales-service.yaml    # Sales service deployment
│   │   └── ingress.yaml          # Ingress configuration
│   └── qa/                       # QA environment
│       ├── postgres.yaml         # PostgreSQL with persistence
│       ├── orders-service.yaml   # Orders with auto-scaling
│       ├── sales-service.yaml    # Sales with auto-scaling
│       └── ingress.yaml          # Ingress configuration
├── docker-compose.yml            # Local development with Docker Compose
├── deploy-k8s.sh                 # Generic Kubernetes deployment script
├── cleanup-k8s.sh                # Kubernetes cleanup script
├── test-local.sh                 # Test script for Docker Compose
└── README.md                     # This file
```

## Quick Start

### Option 1: Local Development with Docker Compose

```bash
# Start all services locally
docker-compose up --build -d

# Services will be available at:
# Orders API: http://localhost:8001
# Sales API:  http://localhost:8002

# Test the services
curl http://localhost:8001/health
curl http://localhost:8002/health

# Create an order
curl -X POST http://localhost:8001/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "John Doe",
    "product_name": "Laptop",
    "quantity": 1,
    "price": 999.99
  }'

# Create a sale
curl -X POST http://localhost:8002/sales \
  -H "Content-Type: application/json" \
  -d '{
    "salesperson_name": "Jane Smith",
    "customer_name": "John Doe",
    "product_name": "Laptop",
    "quantity": 1,
    "unit_price": 999.99,
    "commission_rate": 0.05
  }'

# Stop services
docker-compose down

# Test the deployment
./test-local.sh
```

### Option 2: Kubernetes Deployment

For Kubernetes deployment, you can use the manifests in the `k8s/` directory with any Kubernetes cluster:

```bash
# Deploy to development environment
./deploy-k8s.sh dev

# Deploy to QA environment  
./deploy-k8s.sh qa

# Check deployment status
kubectl get pods -n dev
kubectl get pods -n qa

# Initialize databases (as suggested by the deployment script)
kubectl exec -n dev deployment/postgres -- psql -U user -d postgres -c "CREATE DATABASE orders_db;"
kubectl exec -n dev deployment/postgres -- psql -U user -d postgres -c "CREATE DATABASE sales_db;"

# Access services (port-forward)
kubectl port-forward -n dev service/orders-service 8001:8001
kubectl port-forward -n dev service/sales-service 8002:8002

# Clean up
./cleanup-k8s.sh both
```

## API Usage Examples

### Orders Service

```bash
# Health check
curl http://localhost:8001/health

# Create an order
curl -X POST http://localhost:8001/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "John Doe",
    "product_name": "Laptop",
    "quantity": 1,
    "price": 999.99
  }'

# Get all orders
curl http://localhost:8001/orders

# Get specific order
curl http://localhost:8001/orders/1
```

### Sales Service

```bash
# Health check
curl http://localhost:8002/health

# Create a sale
curl -X POST http://localhost:8002/sales \
  -H "Content-Type: application/json" \
  -d '{
    "salesperson_name": "Jane Smith",
    "customer_name": "John Doe",
    "product_name": "Laptop",
    "quantity": 1,
    "unit_price": 999.99,
    "commission_rate": 0.05
  }'

# Get all sales
curl http://localhost:8002/sales

# Get sales by salesperson
curl http://localhost:8002/sales/salesperson/Jane%20Smith
```

## Development

### Making Changes

1. Make changes to the FastAPI applications in `services/orders/app/` or `services/sales/app/`
2. Rebuild and restart with Docker Compose:
   ```bash
   docker-compose up --build
   ```

### Database Access

When using Docker Compose, you can access PostgreSQL directly:

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U user -d orders_db

# Or for sales database
docker-compose exec postgres psql -U user -d sales_db
```

## Deployment Notes

### Kubernetes Images

The Kubernetes manifests expect images to be available in your cluster. You may need to:

1. Build and push images to a container registry
2. Update the image names in the YAML files
3. Or use a local registry with your Kubernetes cluster

### Environment Configuration

- **Development**: Uses simple PostgreSQL setup with basic resource limits
- **QA**: Includes persistent storage, auto-scaling, and production-like resource limits

### Ingress

The Kubernetes manifests include Ingress configurations for routing traffic to multiple services. Make sure you have an Ingress controller installed in your cluster.

## Troubleshooting

### Docker Compose Issues

```bash
# View logs
docker-compose logs orders-service
docker-compose logs sales-service
docker-compose logs postgres

# Restart services
docker-compose restart

# Clean up
docker-compose down -v
```

### Kubernetes Issues

```bash
# Check pod status
kubectl get pods -n dev

# View logs
kubectl logs -n dev deployment/orders-service
kubectl logs -n dev deployment/sales-service

# Check services
kubectl get services -n dev

# Clean up
kubectl delete namespace dev qa
```