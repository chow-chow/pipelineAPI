CLUSTER_NAME=pipeline-api
IMAGE_NAME=pipeline-api:latest
INGRESS_NGINX_VERSION=4.7.0
NAMESPACE_INGRESS=ingress
NAMESPACE_APP=default
GRAFANA_VERSION=6.58.9
NAMESPACE_MONITORING=monitoring
LOKI_VERSION=5.15.0
NAMESPACE_LOGGING=logging

start: init_cluster install_ingress_nginx init_monitoring load_api import_dashboard show_urls

init_cluster:
	@echo "Initializing Kind cluster..."
	@if ! kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
		kind create cluster --config k8s/config/kind/config.yaml --name $(CLUSTER_NAME); \
	else \
		echo "Cluster $(CLUSTER_NAME) already exists"; \
	fi

load_api: build_image deploy_app

build_image:
	@echo "Building Docker image..."
	@docker build -t $(IMAGE_NAME) -f api/Dockerfile api
	@echo "Loading Docker image into Kind cluster..."
	kind load docker-image $(IMAGE_NAME) --name $(CLUSTER_NAME)

install_ingress_nginx:
	@echo "Installing ingress-nginx..."
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm upgrade ingress-nginx ingress-nginx/ingress-nginx --install --wait \
		--version=$(INGRESS_NGINX_VERSION) \
		--namespace=$(NAMESPACE_INGRESS) --create-namespace \
		--values=k8s/config/ingress-nginx/values.yaml
	@echo "ingress-nginx installed successfully."

deploy_app:
	@echo "Deploying FastAPI app..."
	@kubectl apply -f k8s/config/api/deployment.yaml -n $(NAMESPACE_APP)

init_monitoring: install_prometheus install_loki install_promtail install_grafana

install_prometheus:
	@echo "Installing Prometheus..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm upgrade prometheus prometheus-community/prometheus --install --wait \
		--version=$(PROMETHEUS_VERSION) \
		--namespace=$(NAMESPACE_MONITORING) --create-namespace \
		--values=k8s/config/monitoring/prometheus/values.yaml
	@echo "Prometheus installed successfully."

install_loki:
	@echo "Installing Loki..."
	helm upgrade loki grafana/loki --install --wait \
		--version=$(LOKI_VERSION) \
		--namespace=$(NAMESPACE_LOGGING) --create-namespace \
		--values=k8s/config/loki/values.yaml
	@echo "Loki installed successfully."

install_promtail:
	@echo "Installing Promtail..."
	kubectl apply --filename=k8s/config/promtail/values.yaml
	@echo "Promtail installed successfully."

install_grafana:
	@echo "Installing Grafana..."
	helm repo add grafana https://grafana.github.io/helm-charts
	helm upgrade grafana grafana/grafana --install --wait \
		--version=$(GRAFANA_VERSION) \
		--namespace=$(NAMESPACE_MONITORING) --create-namespace \
		--values=k8s/config/monitoring/grafana/values.yaml
	@echo "Grafana installed successfully."

show_urls:
	@echo "Waiting for Grafana pods to be in Running state..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n $(NAMESPACE_MONITORING) --timeout=120s
	@NODE_IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') && \
	echo "Updating /etc/hosts to include Grafana domain..."; \
	ENTRY="$$NODE_IP monitoring"; \
	echo "Entry to add: $$ENTRY"; \
	if ! grep -q "$$ENTRY" /etc/hosts; then echo "$$ENTRY" | sudo tee -a /etc/hosts > /dev/null; fi; \
	GRAFANA_PASSWORD=$$(kubectl get secret --namespace $(NAMESPACE_MONITORING) grafana -o jsonpath="{.data.admin-password}" | base64 --decode) && \
	echo "============================================================" && \
	echo "Grafana is now accessible at: http://monitoring:30123/grafana" && \
	echo "Login with username: admin and password: $$GRAFANA_PASSWORD" && \
	echo "============================================================"
	@echo "Waiting for API pods to be in Running state..."
	@kubectl wait --for=condition=ready pod -l app=pipeline-api -n $(NAMESPACE_APP) --timeout=120s
	@echo "API pods are now Running."
	@echo "============================================================" && \
	echo "API is now accessible at: http://localhost:30123/api" && \
	echo "============================================================"

import_dashboard:
	@echo "Importing Grafana dashboard..."
	@GRAFANA_PASSWORD=$$(kubectl get secret --namespace $(NAMESPACE_MONITORING) grafana -o jsonpath="{.data.admin-password}" | base64 --decode) && \
	curl -u admin:$$GRAFANA_PASSWORD -X POST 'http://monitoring:30123/grafana/api/dashboards/db' \
	--header 'Content-Type: application/json' \
	--header 'Accept: application/json' \
	--data @k8s/config/monitoring/grafana/dashboard.json
	@echo "Grafana dashboard imported successfully"

uninstall_prometheus:
	@echo "Uninstalling Prometheus..."
	helm uninstall prometheus --namespace $(NAMESPACE_MONITORING)
	@echo "Prometheus uninstalled successfully."

run:
	@echo "Running stern to tail logs for pods starting with 'pipeline-api'..."
	@stern pipeline-api -n $(NAMESPACE_APP) --pod-colors "31, 32, 33, 34, 35"

reload:
	@echo "Building Docker image..."
	@docker build -t $(IMAGE_NAME) -f api/Dockerfile api
	@echo "Loading Docker image into Kind cluster..."
	kind load docker-image $(IMAGE_NAME) --name $(CLUSTER_NAME)
	@echo "Restarting deployment to apply new image..."
	@kubectl rollout restart deployment/pipeline-api -n $(NAMESPACE_APP)
	@echo "Application reloaded successfully."

stop:
	@echo "Deleting Kind cluster..."
	@if kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
		kind delete cluster --name $(CLUSTER_NAME); \
	else \
		echo "Cluster $(CLUSTER_NAME) does not exist"; \
	fi