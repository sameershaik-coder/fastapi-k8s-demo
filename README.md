# FastAPI Microservices with Kubernetes

This project contains two microservices (Orders and Sales) built with FastAPI, PostgreSQL, and deployed on Kubernetes using Minikube.

## Architecture

- **Orders Service**: Manages order operations
- **Sales Service**: Manages sales operations
- **PostgreSQL**: Database for both services
- **Kubernetes**: Container orchestration
- **Minikube**: Local Kubernetes cluster

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

1. **Start Minikube**
   ```bash
   minikube start
   ```

2. **Deploy to Dev Environment**
   ```bash
   kubectl apply -f k8s/dev/
   ```

3. **Deploy to QA Environment**
   ```bash
   kubectl apply -f k8s/qa/
   ```

## Services

### Orders Service
- **Port**: 8001
- **Database**: orders_db
- **Endpoints**: 
  - GET /orders
  - POST /orders
  - GET /orders/{id}

### Sales Service
- **Port**: 8002
- **Database**: sales_db
- **Endpoints**:
  - GET /sales
  - POST /sales
  - GET /sales/{id}

## Environment Management

- **Dev**: Development environment with basic configurations
- **QA**: Quality assurance environment with production-like settings
