CLUSTER_NAME=pipeline-api
IMAGE_NAME=pipeline-api:latest
INGRESS_NGINX_VERSION=4.7.0
NAMESPACE_INGRESS=ingress
NAMESPACE_APP=default
GRAFANA_VERSION=6.58.9
NAMESPACE_MONITORING=monitoring

start: init_cluster load_api init_monitoring

init_cluster:
	@echo "Initializing Kind cluster..."
	@if ! kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
		kind create cluster --config k8s/config/kind/config.yaml --name $(CLUSTER_NAME); \
	else \
		echo "Cluster $(CLUSTER_NAME) already exists"; \
	fi

load_api: build_image install_ingress_nginx deploy_app

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

init_monitoring: install_grafana install_prometheus

install_grafana:
	@echo "Installing Grafana..."
	helm repo add grafana https://grafana.github.io/helm-charts
	helm upgrade grafana grafana/grafana --install --wait \
		--version=$(GRAFANA_VERSION) \
		--namespace=$(NAMESPACE_MONITORING) --create-namespace \
		--values=k8s/config/monitoring/grafana/values.yaml
	@NODE_IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'); \
	echo "Updating /etc/hosts to include Grafana domain..."; \
	ENTRY="$$NODE_IP monitoring"; \
	echo "Entry to add: $$ENTRY"; \
	if ! grep -q "$$ENTRY" /etc/hosts; then echo "$$ENTRY" | sudo tee -a /etc/hosts > /dev/null; fi; \
	echo "Grafana is now accessible at: http://monitoring:30123/grafana"

install_prometheus:
	@echo "Installing Prometheus..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm upgrade prometheus prometheus-community/prometheus --install --wait \
		--version=$(PROMETHEUS_VERSION) \
		--namespace=$(NAMESPACE_MONITORING) --create-namespace \
		--values=k8s/config/monitoring/prometheus/values.yaml
	@echo "Prometheus installed successfully."

uninstall_prometheus:
	@echo "Uninstalling Prometheus..."
	helm uninstall prometheus --namespace $(NAMESPACE_MONITORING)
	@echo "Prometheus uninstalled successfully."

run:
	@echo "Running stern to tail logs for pods starting with 'pipeline-api'..."
	@stern pipeline-api -n $(NAMESPACE_APP) --pod-colors "31, 32, 33, 34"

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