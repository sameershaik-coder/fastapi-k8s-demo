# Kind Setup Guide - FastAPI Microservices

## Overview

This guide explains how to use Kind (Kubernetes in Docker) to deploy and test the FastAPI microservices locally in a realistic Kubernetes environment.

## What is Kind?

Kind (Kubernetes in Docker) is a tool for running local Kubernetes clusters using Docker container "nodes". It's designed for:
- Testing Kubernetes deployments locally
- CI/CD pipelines
- Learning Kubernetes without needing a full cluster

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 Host System                     │
│  ┌─────────────────────────────────────────────┐│
│  │            Kind Cluster                     ││
│  │  ┌─────────────┐  ┌─────────────┐          ││
│  │  │ Control     │  │   Worker    │          ││
│  │  │ Plane       │  │   Node 1    │          ││
│  │  │             │  │             │          ││
│  │  └─────────────┘  └─────────────┘          ││
│  │          │               │                 ││
│  │  ┌─────────────┐  ┌─────────────┐          ││
│  │  │   Worker    │  │   Ingress   │          ││
│  │  │   Node 2    │  │ Controller  │          ││
│  │  │             │  │             │          ││
│  │  └─────────────┘  └─────────────┘          ││
│  └─────────────────────────────────────────────┘│
│                     │                           │
│  ┌─────────────────────────────────────────────┐│
│  │         Local Docker Registry              ││
│  │            :5001                           ││
│  └─────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
                      │
              ┌───────────────┐
              │  Port 80/443  │ ──── http://dev.microservices.local
              └───────────────┘
```

## Features

### Multi-Node Cluster
- 1 Control Plane node
- 2 Worker nodes
- Realistic distributed setup

### Ingress Controller
- NGINX Ingress Controller
- Port 80/443 mapped to host
- Supports real domain names (dev.microservices.local)

### Local Registry
- Docker registry at localhost:5001
- Automatic image loading
- No need for external registries

### Resource Management
- Proper resource limits and requests
- Health checks (liveness/readiness probes)
- Multi-replica deployments

## Quick Start

### Automated Deployment
```bash
# Deploy everything
make kind-deploy

# Test deployment
make kind-test

# View status
make kind-status
```

### Manual Steps
```bash
# 1. Create cluster and registry
./deploy-kind.sh

# 2. Test the deployment
./test-kind.sh

# 3. Check status
./deploy-kind.sh status
```

## Detailed Workflow

### 1. Cluster Creation
```bash
# Creates 3-node cluster with ingress support
kind create cluster --config=kind-config.yaml --name=fastapi-microservices
```

### 2. Registry Setup
```bash
# Creates local registry for images
docker run -d --restart=always -p "127.0.0.1:5001:5000" --name "kind-registry" registry:2
```

### 3. Ingress Installation
```bash
# Installs NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

### 4. Image Building and Loading
```bash
# Build images
docker build -t orders-service:latest ./services/orders/
docker build -t sales-service:latest ./services/sales/

# Load into Kind cluster
kind load docker-image orders-service:latest --name=fastapi-microservices
kind load docker-image sales-service:latest --name=fastapi-microservices
```

### 5. Application Deployment
```bash
# Deploy all resources
kubectl apply -f k8s/kind/
```

### 6. Database Initialization
```bash
# Create databases
kubectl exec -n dev deployment/postgres -- psql -U user -d postgres -c "CREATE DATABASE orders_db;"
kubectl exec -n dev deployment/postgres -- psql -U user -d postgres -c "CREATE DATABASE sales_db;"
```

## Access Methods

### 1. Via Ingress (Recommended)
```bash
# Access through domain names
curl http://dev.microservices.local/orders/health
curl http://dev.microservices.local/sales/health
```

### 2. Via Port Forwarding
```bash
# Setup port forwarding
kubectl port-forward -n dev service/orders-service 8001:8001 &
kubectl port-forward -n dev service/sales-service 8002:8002 &

# Access via localhost
curl http://localhost:8001/health
curl http://localhost:8002/health
```

### 3. Via NodePort (Alternative)
```bash
# Get node IP
kubectl get nodes -o wide

# Use NodeIP:NodePort if services were configured with NodePort
```

## Development Workflow

### Making Code Changes
```bash
# 1. Edit code in services/orders/app/ or services/sales/app/

# 2. Rebuild and redeploy
make kind-rebuild

# 3. Test changes
make kind-test
```

### Viewing Logs
```bash
# Application logs
make logs

# Or specific service
kubectl logs -f deployment/orders-service -n dev
kubectl logs -f deployment/sales-service -n dev
```

### Debugging
```bash
# Pod status
kubectl get pods -n dev

# Describe problematic pods
kubectl describe pod <pod-name> -n dev

# Shell into pods
kubectl exec -it -n dev deployment/orders-service -- /bin/bash
```

## Configuration Files

### kind-config.yaml
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: fastapi-microservices
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
```

### Key Features:
- **Multi-node**: 3 nodes for realistic testing
- **Port mapping**: 80/443 for ingress access
- **Labels**: Marks control-plane as ingress-ready

## Kubernetes Manifests

Located in `k8s/kind/`:

### postgres.yaml
- PostgreSQL database
- ConfigMap for configuration
- EmptyDir for data (non-persistent for local testing)

### orders-service.yaml & sales-service.yaml
- FastAPI applications
- 2 replicas each
- Resource limits and requests
- Liveness and readiness probes
- ClusterIP services

### ingress.yaml
- NGINX Ingress Controller configuration
- Path-based routing (/orders/* and /sales/*)
- CORS configuration
- Host: dev.microservices.local

## Comparison with Other Options

| Feature | Docker Compose | Kind | Minikube | Cloud K8s |
|---------|----------------|------|----------|-----------|
| Setup Speed | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| Resource Usage | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| K8s Realism | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| CI/CD Ready | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| Multi-node | ❌ | ✅ | ❌ | ✅ |
| Ingress | ❌ | ✅ | ✅ | ✅ |

## Best Practices

### Resource Management
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8001
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /health
    port: 8001
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Image Management
- Use `imagePullPolicy: Never` for local images
- Load images with `kind load docker-image`
- Use local registry for complex scenarios

## Troubleshooting

### Common Issues

1. **Cluster won't start**
   ```bash
   # Check Docker
   docker ps
   
   # Delete and recreate
   kind delete cluster --name=fastapi-microservices
   ./deploy-kind.sh
   ```

2. **Images not found**
   ```bash
   # Check loaded images
   docker exec -it fastapi-microservices-control-plane crictl images
   
   # Reload images
   make kind-rebuild
   ```

3. **Ingress not working**
   ```bash
   # Check ingress controller
   kubectl get pods -n ingress-nginx
   
   # Check ingress resource
   kubectl describe ingress -n dev
   
   # Try port-forward
   make port-forward
   ```

4. **DNS issues**
   ```bash
   # Add host entry manually
   echo "127.0.0.1 dev.microservices.local" | sudo tee -a /etc/hosts
   ```

### Useful Commands

```bash
# Cluster management
kind get clusters
kind delete cluster --name=fastapi-microservices

# Image management
kind load docker-image <image:tag> --name=fastapi-microservices
docker exec -it fastapi-microservices-control-plane crictl images

# Debugging
kubectl get all -n dev
kubectl describe pod <pod-name> -n dev
kubectl logs -f deployment/<service-name> -n dev

# Port forwarding
kubectl port-forward -n dev service/orders-service 8001:8001
kubectl port-forward -n dev service/sales-service 8002:8002
```

## Cleanup

```bash
# Complete cleanup
make kind-cleanup

# Or manually
kind delete cluster --name=fastapi-microservices
docker rm -f kind-registry
```

This removes:
- Kind cluster
- Local registry
- All deployed applications
- Host entries remain (remove manually if needed)

## Next Steps

1. **Production Deployment**: Use `k8s/dev/` or `k8s/qa/` manifests with real K8s cluster
2. **CI/CD Integration**: Use Kind in GitHub Actions or other CI systems
3. **Monitoring**: Add Prometheus/Grafana to the cluster
4. **Security**: Add network policies, RBAC, and security contexts
5. **Persistence**: Add persistent volumes for production-like testing
