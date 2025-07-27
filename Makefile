.PHONY: help start-minikube build deploy-dev deploy-qa deploy-all init-db test clean docker-dev logs status

# Default target
help:
	@echo "FastAPI Microservices - Available Commands:"
	@echo ""
	@echo "  make start-minikube  - Start Minikube cluster"
	@echo "  make build          - Build Docker images"
	@echo "  make deploy-dev     - Deploy to DEV environment"
	@echo "  make deploy-qa      - Deploy to QA environment"
	@echo "  make deploy-all     - Deploy to both environments"
	@echo "  make init-db        - Initialize databases"
	@echo "  make docker-dev     - Run with Docker Compose (local dev)"
	@echo "  make test           - Run tests"
	@echo "  make logs           - Show application logs"
	@echo "  make status         - Show cluster status"
	@echo "  make clean          - Clean up deployments"
	@echo ""

start-minikube:
	@echo "🚀 Starting Minikube..."
	minikube start --driver=docker
	minikube addons enable metrics-server

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
	@echo "Orders Service Health Check:"
	@curl -s http://$$(minikube ip):30001/health || curl -s http://localhost:8001/health || echo "Service not available"
	@echo ""
	@echo "Sales Service Health Check:"
	@curl -s http://$$(minikube ip):30002/health || curl -s http://localhost:8002/health || echo "Service not available"

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

clean:
	@echo "🧹 Cleaning up..."
	./cleanup.sh both
	docker-compose down -v 2>/dev/null || true
