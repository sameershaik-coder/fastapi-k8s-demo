# Setup Guide - FastAPI Microservices with Kubernetes

## Prerequisites

Before you begin, ensure you have the following tools installed:

1. **Docker** - Container runtime
2. **Minikube** - Local Kubernetes cluster
3. **kubectl** - Kubernetes command-line tool
4. **Make** - Build automation tool (optional but recommended)

### Installing Prerequisites (Ubuntu/Debian)

```bash
# Install Docker
sudo apt update
sudo apt install docker.io
sudo usermod -aG docker $USER

# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl

# Install Make
sudo apt install make
```

## Quick Start

### Option 1: Using Make (Recommended)

```bash
# 1. Start Minikube
make start-minikube

# 2. Deploy to development environment
make deploy-dev

# 3. Initialize databases
make init-db

# 4. Check status
make status
```

### Option 2: Manual Steps

```bash
# 1. Start Minikube
minikube start

# 2. Deploy services
./deploy.sh dev

# 3. Initialize databases
./init-db.sh
```

### Option 3: Local Development with Docker Compose

```bash
# Start all services locally
make docker-dev

# Or manually
docker-compose up --build
```

## Environment Details

### Development Environment
- **Namespace**: `dev`
- **Replicas**: 2 per service
- **Resources**: Basic resource limits
- **Database**: Simple PostgreSQL setup
- **Access**:
  - Orders Service: `http://<minikube-ip>:30001`
  - Sales Service: `http://<minikube-ip>:30002`

### QA Environment
- **Namespace**: `qa`
- **Replicas**: 3 per service (with auto-scaling)
- **Resources**: Production-like resource limits
- **Database**: PostgreSQL with persistent storage
- **Features**: Health checks, auto-scaling (HPA)
- **Access**:
  - Orders Service: `http://<minikube-ip>:31001`
  - Sales Service: `http://<minikube-ip>:31002`

## API Usage Examples

### Orders Service

```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Health check
curl http://$MINIKUBE_IP:30001/health

# Create an order
curl -X POST http://$MINIKUBE_IP:30001/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "John Doe",
    "product_name": "Laptop",
    "quantity": 1,
    "price": 999.99
  }'

# Get all orders
curl http://$MINIKUBE_IP:30001/orders

# Get specific order
curl http://$MINIKUBE_IP:30001/orders/1
```

### Sales Service

```bash
# Health check
curl http://$MINIKUBE_IP:30002/health

# Create a sale
curl -X POST http://$MINIKUBE_IP:30002/sales \
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
curl http://$MINIKUBE_IP:30002/sales

# Get sales by salesperson
curl http://$MINIKUBE_IP:30002/sales/salesperson/Jane%20Smith
```

## Useful Commands

### Monitoring

```bash
# Watch pod status
kubectl get pods -n dev -w

# View logs
kubectl logs -f deployment/orders-service -n dev
kubectl logs -f deployment/sales-service -n dev

# Port forward for direct access
kubectl port-forward service/orders-service 8001:8001 -n dev
kubectl port-forward service/sales-service 8002:8002 -n dev
```

### Database Access

```bash
# Connect to PostgreSQL in dev
kubectl exec -it deployment/postgres -n dev -- psql -U user -d orders_db

# Connect to PostgreSQL in qa
kubectl exec -it deployment/postgres -n qa -- psql -U qauser -d orders_db
```

### Scaling

```bash
# Manual scaling
kubectl scale deployment orders-service --replicas=5 -n dev

# Check HPA status (QA environment)
kubectl get hpa -n qa
```

## Troubleshooting

### Common Issues

1. **Minikube not starting**
   ```bash
   minikube delete
   minikube start --driver=docker
   ```

2. **Images not found**
   ```bash
   eval $(minikube docker-env)
   make build
   ```

3. **Pods not ready**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   kubectl logs <pod-name> -n <namespace>
   ```

4. **Database connection issues**
   ```bash
   # Check PostgreSQL status
   kubectl get pods -n dev -l app=postgres
   
   # Initialize databases
   make init-db
   ```

### Clean Up

```bash
# Clean up everything
make clean

# Or manually
./cleanup.sh both
docker-compose down -v
```

## Development Workflow

1. **Make changes** to service code
2. **Rebuild** images: `make build`
3. **Redeploy** services: `make deploy-dev`
4. **Test** changes: `make test`
5. **View logs** if needed: `make logs`

## Next Steps

- Add monitoring with Prometheus/Grafana
- Implement CI/CD pipeline
- Add more comprehensive tests
- Set up ingress controller
- Add authentication/authorization
- Implement service mesh (Istio)
