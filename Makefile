.PHONY: help start-minikube build deploy-dev deploy-qa deploy-all init-db test clean docker-dev logs status ingress-info setup-hosts

# Default target
help:
	@echo "FastAPI Microservices - Available Commands:"
	@echo ""
	@echo "  make start-minikube  - Start Minikube cluster with Ingress"
	@echo "  make build          - Build Docker images"
	@echo "  make deploy-dev     - Deploy to DEV environment"
	@echo "  make deploy-qa      - Deploy to QA environment"
	@echo "  make deploy-all     - Deploy to both environments"
	@echo "  make init-db        - Initialize databases"
	@echo "  make docker-dev     - Run with Docker Compose (local dev)"
	@echo "  make test           - Run tests"
	@echo "  make logs           - Show application logs"
	@echo "  make status         - Show cluster status"
	@echo "  make ingress-info   - Show Ingress information"
	@echo "  make setup-hosts    - Add host entries for local testing"
	@echo "  make clean          - Clean up deployments"
	@echo ""

start-minikube:
	@echo "🚀 Starting Minikube with Ingress..."
	minikube start --driver=docker
	minikube addons enable metrics-server
	minikube addons enable ingress
	@echo "✅ Minikube started with Ingress addon enabled"

build:
	@echo "🏗️  Building Docker images..."
	eval $$(minikube docker-env) && \
	docker build -t orders-service:latest ./services/orders/ && \
	docker build -t orders-service:qa ./services/orders/ && \
	docker build -t sales-service:latest ./services/sales/ && \
	docker build -t sales-service:qa ./services/sales/

deploy-dev:
	@echo "🌱 Deploying to DEV environment..."
	./deploy.sh dev

deploy-qa:
	@echo "🧪 Deploying to QA environment..."
	./deploy.sh qa

deploy-all:
	@echo "🚀 Deploying to both environments..."
	./deploy.sh both

init-db:
	@echo "🗄️  Initializing databases..."
	./init-db.sh

docker-dev:
	@echo "🐳 Starting services with Docker Compose..."
	docker-compose up --build -d
	@echo "Services available at:"
	@echo "  Orders: http://localhost:8001"
	@echo "  Sales:  http://localhost:8002"

test:
	@echo "🧪 Running tests..."
	./test.sh

logs:
	@echo "📋 Application logs:"
	@echo "=== Orders Service Logs ==="
	kubectl logs -f deployment/orders-service -n dev --tail=20 || echo "Orders service not found"
	@echo ""
	@echo "=== Sales Service Logs ==="
	kubectl logs -f deployment/sales-service -n dev --tail=20 || echo "Sales service not found"

status:
	@echo "📊 Cluster Status:"
	@echo "=== Minikube Status ==="
	minikube status
	@echo ""
	@echo "=== Pods Status ==="
	kubectl get pods --all-namespaces
	@echo ""
	@echo "=== Services ==="
	kubectl get services --all-namespaces
	@echo ""
	@echo "=== Ingress ==="
	kubectl get ingress --all-namespaces

ingress-info:
	@echo "🌐 Ingress Information:"
	@MINIKUBE_IP=$$(minikube ip) && \
	echo "Minikube IP: $$MINIKUBE_IP" && \
	echo "" && \
	echo "Available URLs:" && \
	echo "  DEV Environment:" && \
	echo "    Base URL: http://$$MINIKUBE_IP" && \
	echo "    Orders:   http://$$MINIKUBE_IP/orders" && \
	echo "    Sales:    http://$$MINIKUBE_IP/sales" && \
	echo "" && \
	echo "  QA Environment:" && \
	echo "    Base URL: http://$$MINIKUBE_IP" && \
	echo "    Orders:   http://$$MINIKUBE_IP/orders" && \
	echo "    Sales:    http://$$MINIKUBE_IP/sales" && \
	echo "    API v1:   http://$$MINIKUBE_IP/api/v1/{orders|sales}" && \
	echo "" && \
	echo "Host Headers:" && \
	echo "  DEV: -H 'Host: dev.microservices.local'" && \
	echo "  QA:  -H 'Host: qa.microservices.local'"

setup-hosts:
	@echo "🔧 Setting up host entries..."
	@MINIKUBE_IP=$$(minikube ip) && \
	echo "Adding entries to /etc/hosts:" && \
	echo "$$MINIKUBE_IP dev.microservices.local" | sudo tee -a /etc/hosts && \
	echo "$$MINIKUBE_IP qa.microservices.local" | sudo tee -a /etc/hosts && \
	echo "✅ Host entries added. You can now use:" && \
	echo "  http://dev.microservices.local" && \
	echo "  http://qa.microservices.local"

clean:
	@echo "🧹 Cleaning up..."
	./cleanup.sh both
	docker-compose down -v 2>/dev/null || true
