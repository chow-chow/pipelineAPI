CLUSTER_NAME=pipeline-api
IMAGE_NAME=pipeline-api:latest
INGRESS_NGINX_VERSION=4.7.0
NAMESPACE_INGRESS=ingress
NAMESPACE_APP=default

start: init_cluster load_api

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

stop:
	@echo "Deleting Kind cluster..."
	@if kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
		kind delete cluster --name $(CLUSTER_NAME); \
	else \
		echo "Cluster $(CLUSTER_NAME) does not exist"; \
	fi