.PHONY: help kind-deploy kind-test kind-status kind-cleanup kind-rebuild docker-dev logs port-forward clean-all

# Default target
help:
	@echo "FastAPI Microservices with Kind - Available Commands:"
	@echo ""
	@echo "🚀 Kind Deployment:"
	@echo "  make kind-deploy     - Deploy complete stack with Kind"
	@echo "  make kind-test       - Run tests against Kind deployment"
	@echo "  make kind-status     - Show Kind cluster status"
	@echo "  make kind-cleanup    - Remove Kind cluster and registry"
	@echo "  make kind-rebuild    - Rebuild and redeploy images"
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
