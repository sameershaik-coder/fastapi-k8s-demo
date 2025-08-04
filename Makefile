.PHONY: help kind-deploy kind-test kind-status kind-cleanup kind-cleanup-hosts kind-rebuild docker-dev logs port-forward clean-all

# Default target
help:
	@echo "FastAPI Microservices with Kind - Available Commands:"
	@echo ""
	@echo "🚀 Kind Deployment:"
	@echo "  make kind-deploy       - Deploy complete stack with Kind"
	@echo "  make kind-test         - Run tests against Kind deployment"
	@echo "  make kind-status       - Show Kind cluster status"
	@echo "  make kind-cleanup      - Remove Kind cluster, registry, and hosts"
	@echo "  make kind-cleanup-hosts - Remove only host entries"
	@echo "  make kind-rebuild      - Rebuild and redeploy images"
	@echo "  make kind-debug        - Debug deployment issues"
	@echo "  make kind-db-check     - Check external database connectivity"
	@echo ""
	@echo "🐳 Local Development:"
	@echo "  make docker-dev      - Run with Docker Compose (local dev)"
	@echo "  make test-local      - Test Docker Compose deployment"
	@echo ""
	@echo "🔧 Utilities:"
	@echo "  make logs            - Show application logs (Kind)"
	@echo "  make port-forward    - Setup port forwarding for direct access"
	@echo "  make clean-all       - Clean both Kind and Docker Compose"
	@echo ""

kind-deploy:
	@echo "🚀 Deploying FastAPI Microservices with Kind..."
	@echo "🔍 Checking prerequisites..."
	@if ! command -v kind >/dev/null 2>&1; then \
		echo "❌ Kind is not installed. Please install Kind first."; \
		exit 1; \
	fi
	@if ! command -v kubectl >/dev/null 2>&1; then \
		echo "❌ kubectl is not installed. Please install kubectl first."; \
		exit 1; \
	fi
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "❌ Docker is not installed. Please install Docker first."; \
		exit 1; \
	fi
	@echo "✅ Prerequisites check passed"
	./deploy-kind.sh deploy

kind-test:
	@echo "🧪 Testing Kind deployment..."
	./test-kind.sh

kind-status:
	@echo "📊 Checking Kind cluster status..."
	./deploy-kind.sh status

kind-cleanup:
	@echo "🧹 Cleaning up Kind deployment..."
	./deploy-kind.sh cleanup

kind-cleanup-hosts:
	@echo "🧹 Cleaning up host entries only..."
	./deploy-kind.sh cleanup-hosts

kind-rebuild:
	@echo "🔄 Rebuilding and redeploying images..."
	@if kind get clusters | grep -q "fastapi-microservices"; then \
		echo "Building new images..."; \
		docker build -t orders-service:latest ./services/orders/; \
		docker build -t sales-service:latest ./services/sales/; \
		echo "Loading images into Kind cluster..."; \
		kind load docker-image orders-service:latest --name=fastapi-microservices; \
		kind load docker-image sales-service:latest --name=fastapi-microservices; \
		echo "Restarting deployments..."; \
		kubectl rollout restart deployment/orders-service -n dev; \
		kubectl rollout restart deployment/sales-service -n dev; \
		kubectl rollout status deployment/orders-service -n dev; \
		kubectl rollout status deployment/sales-service -n dev; \
		echo "✅ Rebuild completed"; \
	else \
		echo "❌ Kind cluster not found. Run 'make kind-deploy' first."; \
	fi

# Troubleshooting target
kind-debug:
	@echo "🔍 Debugging Kind deployment issues..."
	@if kind get clusters | grep -q "fastapi-microservices"; then \
		echo "=== Cluster Status ==="; \
		kubectl get nodes; \
		echo ""; \
		echo "=== Pod Status ==="; \
		kubectl get pods -A; \
		echo ""; \
		echo "=== Service Status ==="; \
		kubectl get services -n dev; \
		echo ""; \
		echo "=== External Database Status ==="; \
		psql "postgresql://k8s_user:k8s_password@localhost:5432/orders_db" -c "SELECT 'orders_db connected' as status;" || echo "❌ Cannot connect to orders_db"; \
		psql "postgresql://k8s_user:k8s_password@localhost:5432/sales_db" -c "SELECT 'sales_db connected' as status;" || echo "❌ Cannot connect to sales_db"; \
		echo ""; \
		echo "=== Recent Events ==="; \
		kubectl get events -n dev --sort-by='.lastTimestamp' | tail -10; \
		echo ""; \
		echo "=== Failing Pod Logs ==="; \
		for pod in $$(kubectl get pods -n dev --field-selector=status.phase=Failed -o name 2>/dev/null); do \
			echo "Logs for $$pod:"; \
			kubectl logs $$pod -n dev --tail=20; \
			echo ""; \
		done; \
	else \
		echo "❌ Kind cluster not found."; \
	fi

# Database connectivity check
kind-db-check:
	@echo "🗄️  Checking external PostgreSQL database connectivity..."
	@if command -v psql >/dev/null 2>&1; then \
		echo "Testing orders_db connection..."; \
		psql "postgresql://k8s_user:k8s_password@localhost:5432/orders_db" -c "SELECT version();" && echo "✅ orders_db connection successful" || echo "❌ orders_db connection failed"; \
		echo ""; \
		echo "Testing sales_db connection..."; \
		psql "postgresql://k8s_user:k8s_password@localhost:5432/sales_db" -c "SELECT version();" && echo "✅ sales_db connection successful" || echo "❌ sales_db connection failed"; \
		echo ""; \
		echo "Database list:"; \
		psql "postgresql://k8s_user:k8s_password@localhost:5432/postgres" -c "\l"; \
	else \
		echo "❌ psql not found. Please install postgresql-client."; \
	fi

docker-dev:
	@echo "🐳 Starting services with Docker Compose..."
	docker-compose up --build -d
	@echo "Services available at:"
	@echo "  Orders: http://localhost:8001"
	@echo "  Sales:  http://localhost:8002"

test-local:
	@echo "🧪 Testing Docker Compose deployment..."
	./test-local.sh

logs:
	@echo "📋 Application logs (Kind deployment):"
	@if kind get clusters | grep -q "fastapi-microservices"; then \
		echo "=== Orders Service Logs ==="; \
		kubectl logs --tail=20 deployment/orders-service -n dev || echo "Orders service not found"; \
		echo ""; \
		echo "=== Sales Service Logs ==="; \
		kubectl logs --tail=20 deployment/sales-service -n dev || echo "Sales service not found"; \
		echo ""; \
		echo "=== PostgreSQL Logs ==="; \
		kubectl logs --tail=10 deployment/postgres -n dev || echo "PostgreSQL not found"; \
	else \
		echo "❌ Kind cluster not found. Run 'make kind-deploy' first."; \
	fi

port-forward:
	@echo "🔌 Setting up port forwarding..."
	@if kind get clusters | grep -q "fastapi-microservices"; then \
		echo "Port forwarding will run in background. Use Ctrl+C to stop."; \
		echo "Services will be available at:"; \
		echo "  Orders: http://localhost:8001"; \
		echo "  Sales:  http://localhost:8002"; \
		echo ""; \
		kubectl port-forward -n dev service/orders-service 8001:8001 & \
		kubectl port-forward -n dev service/sales-service 8002:8002 & \
		echo "Port forwarding started. Press Ctrl+C to stop."; \
		wait; \
	else \
		echo "❌ Kind cluster not found. Run 'make kind-deploy' first."; \
	fi

clean-all:
	@echo "🧹 Cleaning up everything..."
	./deploy-kind.sh cleanup || true
	docker-compose down -v 2>/dev/null || true
	@echo "✅ All cleanup completed"

# Quick development workflow targets
dev: docker-dev test-local
	@echo "🎉 Local development environment ready!"

kind: kind-deploy kind-test
	@echo "🎉 Kind deployment completed and tested!"

# Show cluster information
info:
	@if kind get clusters | grep -q "fastapi-microservices"; then \
		echo "📊 Kind Cluster Information:"; \
		kubectl cluster-info --context kind-fastapi-microservices; \
		echo ""; \
		echo "📦 Deployed Resources:"; \
		kubectl get all -n dev; \
		echo ""; \
		echo "🌐 Ingress:"; \
		kubectl get ingress -n dev; \
	else \
		echo "❌ Kind cluster not found."; \
	fi
