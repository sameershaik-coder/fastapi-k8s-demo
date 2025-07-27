# FastAPI Microservices with Kind

This project contains two microservices (Orders and Sales) built with FastAPI and PostgreSQL. It can be deployed locally using Docker Compose or on a local Kubernetes cluster using Kind (Kubernetes in Docker).

## Architecture

- **Orders Service**: Manages order operations
- **Sales Service**: Manages sales operations
- **PostgreSQL**: Database for both services
- **Docker Compose**: Local development environment
- **Kind**: Local Kubernetes cluster for testing Kubernetes deployments
- **Ingress**: NGINX Ingress Controller for routing in Kind

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
│   ├── dev/                      # Development environment (generic K8s)
│   ├── qa/                       # QA environment (generic K8s)
│   └── kind/                     # Kind-specific manifests
│       ├── postgres.yaml         # PostgreSQL deployment
│       ├── orders-service.yaml   # Orders service deployment
│       ├── sales-service.yaml    # Sales service deployment
│       └── ingress.yaml          # Ingress configuration
├── docker-compose.yml            # Local development with Docker Compose
├── kind-config.yaml              # Kind cluster configuration
├── deploy-kind.sh                # Kind deployment script
├── test-kind.sh                  # Kind testing script
├── deploy-k8s.sh                 # Generic Kubernetes deployment script
├── cleanup-k8s.sh                # Kubernetes cleanup script
├── test-local.sh                 # Test script for Docker Compose
├── Makefile                      # Command shortcuts
├── KIND-SETUP.md                 # Detailed Kind setup guide
└── README.md                     # This file
```

## Quick Start

### Prerequisites

- **Docker** - Container runtime
- **Kind** - Kubernetes in Docker (for local K8s testing)
- **kubectl** - Kubernetes command-line tool

#### Installing Prerequisites

```bash
# Install Docker (if not already installed)
# Ubuntu/Debian:
sudo apt update && sudo apt install docker.io
sudo usermod -aG docker $USER

# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
```

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

# Test with the test script
./test-local.sh

# Stop services
docker-compose down
```

### Option 2: Kind (Local Kubernetes) Deployment

# Complete deployment
make kind-deploy

# Test everything
make kind-test

# Make code changes, then rebuild
make kind-rebuild

# View logs
make logs

# Clean up
make kind-cleanup

```bash
# Deploy complete stack with Kind (recommended)
make kind-deploy
# OR manually:
./deploy-kind.sh

# Test the deployment
make kind-test
# OR manually:
./test-kind.sh

# Access services via Ingress
curl http://dev.microservices.local/orders/health
curl http://dev.microservices.local/sales/health

# View cluster status
make kind-status

# Clean up
make kind-cleanup
```

> 📖 **For detailed Kind setup information, see [KIND-SETUP.md](KIND-SETUP.md)**

### Option 3: Quick Commands with Makefile

```bash
# See all available commands
make help

# Local development workflow
make docker-dev        # Start with Docker Compose
make test-local        # Test local deployment

# Kind workflow  
make kind              # Deploy and test with Kind
make kind-rebuild      # Rebuild images and redeploy
make logs              # View application logs
make port-forward      # Access services directly

# Cleanup
make clean-all         # Clean everything
```

## API Usage Examples

### Via Kind Deployment (Ingress)

```bash
# Health checks
curl http://dev.microservices.local/orders/health
curl http://dev.microservices.local/sales/health

# Create an order
curl -X POST http://dev.microservices.local/orders/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "John Doe",
    "product_name": "Laptop",
    "quantity": 1,
    "price": 999.99
  }'

# Get all orders
curl http://dev.microservices.local/orders/orders

# Create a sale
curl -X POST http://dev.microservices.local/sales/sales \
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
curl http://dev.microservices.local/sales/sales
```

### Via Docker Compose (Local Development)

```bash
# Health checks
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

# Get all orders
curl http://localhost:8001/orders

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
```

### Via Port Forwarding (Kind/K8s)

```bash
# Setup port forwarding
make port-forward

# Or manually:
kubectl port-forward -n dev service/orders-service 8001:8001 &
kubectl port-forward -n dev service/sales-service 8002:8002 &

# Then use localhost URLs (same as Docker Compose examples above)
curl http://localhost:8001/health
curl http://localhost:8002/health
```

## Development

### Making Changes

1. **Make changes** to the FastAPI applications in `services/orders/app/` or `services/sales/app/`
2. **For Docker Compose**: Rebuild and restart:
   ```bash
   docker-compose up --build
   ```
3. **For Kind**: Rebuild and redeploy:
   ```bash
   make kind-rebuild
   ```

### Database Access

#### Docker Compose
```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U user -d orders_db
# Or for sales database
docker-compose exec postgres psql -U user -d sales_db
```

#### Kind/Kubernetes
```bash
# Connect to PostgreSQL
kubectl exec -it -n dev deployment/postgres -- psql -U user -d orders_db
# Or for sales database  
kubectl exec -it -n dev deployment/postgres -- psql -U user -d sales_db
```

### Monitoring and Debugging

#### Kind Deployment
```bash
# View logs
make logs

# Or manually:
kubectl logs -f deployment/orders-service -n dev
kubectl logs -f deployment/sales-service -n dev

# Check pod status
kubectl get pods -n dev

# Describe problematic pods
kubectl describe pod <pod-name> -n dev

# Port forward for direct access
make port-forward
```

#### Docker Compose
```bash
# View logs
docker-compose logs orders-service
docker-compose logs sales-service
docker-compose logs postgres

# Check container status
docker-compose ps
```

## Deployment Notes

### Kind vs Docker Compose

- **Docker Compose**: Best for rapid local development and testing
- **Kind**: Best for testing Kubernetes deployments locally, CI/CD, and learning K8s

### Kind Features

- **Local Registry**: Automatically creates a local Docker registry for images
- **Ingress Controller**: NGINX Ingress Controller for realistic routing
- **Multi-node**: 3-node cluster (1 control-plane, 2 workers) for realistic testing
- **Host Network**: Port 80/443 mapped for easy access via localhost

### Image Management

The Kind deployment automatically:
1. Builds Docker images locally
2. Loads them into the Kind cluster
3. Uses `imagePullPolicy: Never` to use local images

### Generic Kubernetes

The `k8s/dev/` and `k8s/qa/` directories contain generic Kubernetes manifests that work with any cluster. Use these for:
- Production deployments
- Cloud Kubernetes services (EKS, GKE, AKS)
- Self-managed clusters

## Troubleshooting

### Kind Issues

```bash
# Check if Kind cluster exists
kind get clusters

# Check cluster status
kubectl cluster-info --context kind-fastapi-microservices

# Recreate cluster if needed
make kind-cleanup
make kind-deploy

# Check if images are loaded
docker exec -it fastapi-microservices-control-plane crictl images

# Reload images if needed
make kind-rebuild
```

### Ingress Issues

```bash
# Check Ingress controller status
kubectl get pods -n ingress-nginx

# Check Ingress configuration
kubectl get ingress -n dev
kubectl describe ingress microservices-ingress -n dev

# Test with port-forward as fallback
make port-forward
```

### DNS/Host Issues

```bash
# Check if host entry exists
grep "dev.microservices.local" /etc/hosts

# Add manually if needed
echo "127.0.0.1 dev.microservices.local" | sudo tee -a /etc/hosts

# Test with curl and explicit Host header
curl -H "Host: dev.microservices.local" http://127.0.0.1/orders/health
```

### Application Issues

```bash
# Check pod status
kubectl get pods -n dev

# View detailed pod information
kubectl describe pod <pod-name> -n dev

# Check application logs
kubectl logs -f deployment/orders-service -n dev
kubectl logs -f deployment/sales-service -n dev

# Check database connectivity
kubectl exec -it -n dev deployment/postgres -- pg_isready -U user
```

### Docker Compose Issues

```bash
# View logs
docker-compose logs orders-service
docker-compose logs sales-service
docker-compose logs postgres

# Restart services
docker-compose restart

# Clean rebuild
docker-compose down -v
docker-compose up --build
```

### General Cleanup

```bash
# Clean everything
make clean-all

# Or step by step:
make kind-cleanup      # Remove Kind cluster
docker-compose down -v # Remove Docker Compose
docker system prune    # Clean Docker system
```