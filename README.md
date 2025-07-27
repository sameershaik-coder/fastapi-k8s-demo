# FastAPI Microservices with Kubernetes

This project contains two microservices (Orders and Sales) built with FastAPI, PostgreSQL, and deployed on Kubernetes using Minikube with Ingress controller.

## Architecture

- **Orders Service**: Manages order operations
- **Sales Service**: Manages sales operations
- **PostgreSQL**: Database for both services
- **Kubernetes**: Container orchestration
- **Minikube**: Local Kubernetes cluster
- **Ingress**: Single entry point for all services

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
│   │   └── sales-service.yaml    # Sales service deployment
│   └── qa/                       # QA environment
│       ├── postgres.yaml         # PostgreSQL with persistence
│       ├── orders-service.yaml   # Orders with auto-scaling
│       └── sales-service.yaml    # Sales with auto-scaling
├── deploy.sh                     # Deployment script
├── cleanup.sh                    # Cleanup script
├── init-db.sh                    # Database initialization
├── test.sh                       # Testing script
├── docker-compose.yml            # Local development
├── Makefile                      # Command shortcuts
├── SETUP.md                      # Detailed setup guide
└── README.md                     # This file
```

## Quick Start

# Start Minikube with Ingress
make start-minikube

# Deploy to dev environment
make deploy-dev

# Initialize databases
make init-db

# Get access information
make ingress-info

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Access via Ingress (with Host header)
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/orders/health
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/sales/health

# Setup host entries for easier access
make setup-hosts

# Then access directly
curl http://dev.microservices.local/orders/health
curl http://qa.microservices.local/api/v1/sales/health

# Run automated tests (updated for Ingress)
make test

# Via Ingress (single IP, different paths)
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/orders/orders
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/sales/sales

# Create order via Ingress
curl -H "Host: dev.microservices.local" \
  -X POST http://$MINIKUBE_IP/orders/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_name": "John", "product_name": "Laptop", "quantity": 1, "price": 999.99}'