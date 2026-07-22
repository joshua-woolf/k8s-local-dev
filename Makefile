SHELL := /bin/bash
.DEFAULT_GOAL := help
.NOTPARALLEL:

CLUSTER_NAME ?= local-dev
KUBE_CONTEXT ?= kind-$(CLUSTER_NAME)
IMAGE ?=
CONFIRM ?=
DASHBOARD_IMAGE ?= local/dashboard
DASHBOARD_TAG ?= dev
PLAYWRIGHT_CHANNEL ?= chrome

.PHONY: help doctor cluster helm-core helm-full require-ca tls trust untrust core-resources full-resources dashboard-image dashboard up-core up status ports load test validate smoke reset

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

doctor: ## Check local prerequisites and Docker availability
	@missing=0; \
	for command in docker kind kubectl helm helmfile mkcert; do \
		if ! command -v "$$command" >/dev/null 2>&1; then \
			echo "Missing required command: $$command"; \
			missing=1; \
		fi; \
	done; \
	test "$$missing" -eq 0
	@docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }

cluster: ## Create the Kind cluster if it does not exist
	@if kind get clusters 2>/dev/null | grep -qx "$(CLUSTER_NAME)"; then \
		echo "Kind cluster $(CLUSTER_NAME) already exists"; \
	else \
		kind create cluster --name "$(CLUSTER_NAME)" --config kind.yaml; \
	fi
	@kubectl config use-context "$(KUBE_CONTEXT)" >/dev/null

helm-core: ## Reconcile the lightweight platform controllers
	helmfile --selector profile=core sync

helm-full: ## Reconcile all platform controllers
	helmfile sync

require-ca:
	@test -s .state/mkcert/rootCA.pem -a -s .state/mkcert/rootCA-key.pem || { echo "Local CA not found. Run 'make trust' first."; exit 1; }

tls: require-ca ## Synchronize the local CA and ClusterIssuer into the cluster
	@CLUSTER_NAME="$(CLUSTER_NAME)" KUBE_CONTEXT="$(KUBE_CONTEXT)" ./scripts/sync-ca.sh

trust: ## Generate and trust the dedicated local development CA
	@./scripts/trust-ca.sh
	@if kind get clusters 2>/dev/null | grep -qx "$(CLUSTER_NAME)" && \
		kubectl --context "$(KUBE_CONTEXT)" -n cert-manager get deployment cert-manager >/dev/null 2>&1; then \
		CLUSTER_NAME="$(CLUSTER_NAME)" KUBE_CONTEXT="$(KUBE_CONTEXT)" ./scripts/sync-ca.sh; \
	else \
		echo "CA is trusted. It will be synchronized on the next 'make up'."; \
	fi

untrust: ## Remove this repository's CA from the host trust stores
	@./scripts/untrust-ca.sh

core-resources: ## Reconcile observability, Postgres, and pgAdmin resources
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/namespaces.yaml
	@CLUSTER_NAME="$(CLUSTER_NAME)" KUBE_CONTEXT="$(KUBE_CONTEXT)" ./scripts/sync-data-secrets.sh
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/observability/
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/postgres/

full-resources: core-resources ## Reconcile ClickHouse, Kafka, and Kafbat resources
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/clickhouse/
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/kafka/
	@CLUSTER_NAME="$(CLUSTER_NAME)" KUBE_CONTEXT="$(KUBE_CONTEXT)" ./scripts/sync-policies.sh

dashboard-image: cluster ## Build and load the dashboard image into Kind
	docker build --tag "$(DASHBOARD_IMAGE):$(DASHBOARD_TAG)" --file src/dashboard/server.Dockerfile src/dashboard
	kind load docker-image "$(DASHBOARD_IMAGE):$(DASHBOARD_TAG)" --name "$(CLUSTER_NAME)"

dashboard: dashboard-image ## Install or refresh the dashboard
	helm upgrade dashboard charts/dashboard --install --rollback-on-failure --create-namespace --namespace dashboard --timeout 5m --wait \
		--set-string image.repository="$(DASHBOARD_IMAGE)" \
		--set-string image.tag="$(DASHBOARD_TAG)"
	@kubectl --context "$(KUBE_CONTEXT)" --namespace dashboard rollout restart deployment/dashboard
	@kubectl --context "$(KUBE_CONTEXT)" --namespace dashboard rollout status deployment/dashboard --timeout=180s

up-core: doctor require-ca cluster helm-core tls core-resources dashboard ## Create the lightweight local cluster
	@$(MAKE) --no-print-directory status

up: doctor require-ca cluster helm-full tls full-resources dashboard ## Create the complete local cluster
	@$(MAKE) --no-print-directory status

status: ## Show cluster nodes, releases, pods, and ingresses
	@kubectl --context "$(KUBE_CONTEXT)" get nodes
	@helm --kube-context "$(KUBE_CONTEXT)" list --all-namespaces
	@kubectl --context "$(KUBE_CONTEXT)" get pods --all-namespaces
	@kubectl --context "$(KUBE_CONTEXT)" get ingress --all-namespaces 2>/dev/null || true

ports: ## Print host access details for data services
	@echo "Postgres:   kubectl --context $(KUBE_CONTEXT) -n data port-forward service/postgres-rw 5432:5432"
	@echo "ClickHouse: kubectl --context $(KUBE_CONTEXT) -n data port-forward service/clickhouse 8123:8123"
	@echo "Kafka:      kafka.k8s.localhost:9094 (broker metadata uses port 9095)"

load: ## Load IMAGE into the Kind cluster
	@test -n "$(IMAGE)" || { echo "Usage: make load IMAGE=example/app:dev"; exit 1; }
	kind load docker-image "$(IMAGE)" --name "$(CLUSTER_NAME)"

test: ## Run dashboard lint and unit tests
	cd src/dashboard && npm_config_cache="$(CURDIR)/.state/npm-cache" npm ci && npm run lint && npm test

validate: ## Render and validate charts, manifests, scripts, and dashboard code
	@mkdir -p .rendered
	helmfile template > .rendered/platform.yaml
	helm lint charts/dashboard
	helm template dashboard charts/dashboard --namespace dashboard > .rendered/dashboard.yaml
	@find manifests -name '*.yaml' -print0 | xargs -0 kubeconform -strict -ignore-missing-schemas -summary
	@kubeconform -strict -ignore-missing-schemas -summary .rendered/platform.yaml .rendered/dashboard.yaml
	@shellcheck scripts/*.sh
	@$(MAKE) --no-print-directory test

smoke: require-ca ## Run cluster and browser smoke tests
	@CLUSTER_NAME="$(CLUSTER_NAME)" KUBE_CONTEXT="$(KUBE_CONTEXT)" ./scripts/smoke-test.sh
	cd src/dashboard && NODE_EXTRA_CA_CERTS="$(CURDIR)/.state/mkcert/rootCA.pem" \
		PLAYWRIGHT_CHANNEL="$(PLAYWRIGHT_CHANNEL)" npm run test:smoke

reset: ## Delete the cluster and all local cluster data (requires CONFIRM=1)
	@test "$(CONFIRM)" = "1" || { echo "This deletes the cluster and every PVC. Re-run as: make reset CONFIRM=1"; exit 1; }
	kind delete cluster --name "$(CLUSTER_NAME)"
