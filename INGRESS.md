# Ingress Setup Guide - FastAPI Microservices

## Overview

This guide explains how to use the Ingress controller to serve multiple FastAPI microservices under a single port with proper routing.

## Architecture

The Ingress controller acts as a reverse proxy, routing requests to the appropriate backend services based on URL paths:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Client        │    │  Ingress         │    │  Backend        │
│                 │    │  Controller      │    │  Services       │
│                 │────┤                  │────┤                 │
│ HTTP Request    │    │  nginx           │    │ orders-service  │
│                 │    │                  │    │ sales-service   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Routing Rules

### Development Environment (dev.microservices.local)

| Path | Target Service | Description |
|------|----------------|-------------|
| `/orders/*` | orders-service:8001 | Orders API endpoints |
| `/sales/*` | sales-service:8002 | Sales API endpoints |
| `/*` | orders-service:8001 | Default fallback |

### QA Environment (qa.microservices.local)

| Path | Target Service | Description |
|------|----------------|-------------|
| `/orders/*` | orders-service:8001 | Orders API endpoints |
| `/sales/*` | sales-service:8002 | Sales API endpoints |
| `/api/v1/orders/*` | orders-service:8001 | Versioned Orders API |
| `/api/v1/sales/*` | sales-service:8002 | Versioned Sales API |
| `/*` | orders-service:8001 | Default fallback |

## Quick Start

### 1. Deploy with Ingress

```bash
# Start Minikube with Ingress
make start-minikube

# Deploy to dev environment
make deploy-dev

# Initialize databases
make init-db

# Get Ingress information
make ingress-info
```

### 2. Access Services

```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Access via Ingress (with Host header)
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/orders/health
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/sales/health

# Optional: Add host entries for easier access
make setup-hosts

# Then access directly
curl http://dev.microservices.local/orders/health
curl http://qa.microservices.local/sales/health
```

## Usage Examples

### Orders Service via Ingress

```bash
MINIKUBE_IP=$(minikube ip)

# Health check
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/orders/health

# Get all orders
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/orders/orders

# Create an order
curl -H "Host: dev.microservices.local" \
  -X POST http://$MINIKUBE_IP/orders/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "John Doe",
    "product_name": "Laptop",
    "quantity": 1,
    "price": 999.99
  }'

# Get specific order
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/orders/orders/1
```

### Sales Service via Ingress

```bash
# Health check
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/sales/health

# Get all sales
curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/sales/sales

# Create a sale
curl -H "Host: dev.microservices.local" \
  -X POST http://$MINIKUBE_IP/sales/sales \
  -H "Content-Type: application/json" \
  -d '{
    "salesperson_name": "Jane Smith",
    "customer_name": "John Doe",
    "product_name": "Laptop",
    "quantity": 1,
    "unit_price": 999.99,
    "commission_rate": 0.05
  }'
```

### QA Environment with API Versioning

```bash
# Using versioned endpoints
curl -H "Host: qa.microservices.local" http://$MINIKUBE_IP/api/v1/orders/health
curl -H "Host: qa.microservices.local" http://$MINIKUBE_IP/api/v1/sales/health

# Regular endpoints still work
curl -H "Host: qa.microservices.local" http://$MINIKUBE_IP/orders/health
curl -H "Host: qa.microservices.local" http://$MINIKUBE_IP/sales/health
```

## Features

### Path-based Routing
- Routes requests based on URL paths
- Supports regex patterns for flexible routing
- Automatic path rewriting to backend services

### CORS Support
- Enabled for all origins (configurable)
- Supports all HTTP methods
- Proper handling of preflight requests

### Rate Limiting (QA Environment)
- 100 requests per minute per IP
- Helps prevent abuse and ensures fair usage

### SSL/TLS Support (Future Enhancement)
```yaml
spec:
  tls:
  - hosts:
    - dev.microservices.local
    - qa.microservices.local
    secretName: microservices-tls
```

## Monitoring

### Check Ingress Status

```bash
# View Ingress resources
kubectl get ingress --all-namespaces

# Describe Ingress for details
kubectl describe ingress microservices-ingress -n dev

# Check Ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Test Connectivity

```bash
# Run automated tests
make test

# Manual testing
./test.sh
```

## Troubleshooting

### Common Issues

1. **Ingress not working**
   ```bash
   # Check if Ingress addon is enabled
   minikube addons list | grep ingress
   
   # Enable if disabled
   minikube addons enable ingress
   ```

2. **Host header issues**
   ```bash
   # Always include Host header when testing
   curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/orders/health
   
   # Or add entries to /etc/hosts
   make setup-hosts
   ```

3. **502 Bad Gateway**
   ```bash
   # Check if backend services are running
   kubectl get pods -n dev
   
   # Check service endpoints
   kubectl get endpoints -n dev
   
   # Check logs
   kubectl logs deployment/orders-service -n dev
   ```

4. **Path rewriting issues**
   ```bash
   # Check Ingress annotations
   kubectl describe ingress microservices-ingress -n dev
   
   # Verify backend service paths
   curl -H "Host: dev.microservices.local" http://$MINIKUBE_IP/orders/
   ```

## Advanced Configuration

### Custom Annotations

You can add more annotations to customize Ingress behavior:

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "false"
  nginx.ingress.kubernetes.io/use-regex: "true"
  nginx.ingress.kubernetes.io/rewrite-target: /$2
  nginx.ingress.kubernetes.io/rate-limit: "100"
  nginx.ingress.kubernetes.io/rate-limit-window: "1m"
  nginx.ingress.kubernetes.io/proxy-body-size: "50m"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
```

### Multiple Domains

```yaml
spec:
  rules:
  - host: orders.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: orders-service
            port:
              number: 8001
  - host: sales.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sales-service
            port:
              number: 8002
```

## Benefits of Using Ingress

1. **Single Entry Point**: All services accessible through one IP/port
2. **Path-based Routing**: Route to different services based on URL paths
3. **SSL Termination**: Handle SSL/TLS at the Ingress level
4. **Load Balancing**: Distribute traffic across multiple replicas
5. **Rate Limiting**: Control API usage and prevent abuse
6. **CORS Handling**: Centralized CORS configuration
7. **Authentication**: Add authentication at the Ingress level (future)
8. **Monitoring**: Centralized access logs and metrics
