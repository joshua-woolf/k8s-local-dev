SHELL := /bin/bash
.DEFAULT_GOAL := help
.NOTPARALLEL:

CLUSTER_NAME ?= local-dev
KUBE_CONTEXT ?= kind-$(CLUSTER_NAME)
IMAGE ?=
CONFIRM ?=

.PHONY: help doctor cluster helm-core helm-full require-ca tls trust untrust core-resources full-resources up-core up status ports load reset

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

core-resources: ## Reconcile observability and Postgres resources
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/namespaces.yaml
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/observability/
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/postgres/

full-resources: core-resources ## Reconcile ClickHouse and Kafka resources
	@CLUSTER_NAME="$(CLUSTER_NAME)" KUBE_CONTEXT="$(KUBE_CONTEXT)" ./scripts/sync-data-secrets.sh
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/clickhouse/
	@kubectl --context "$(KUBE_CONTEXT)" apply --filename manifests/kafka/
	@CLUSTER_NAME="$(CLUSTER_NAME)" KUBE_CONTEXT="$(KUBE_CONTEXT)" ./scripts/sync-policies.sh

up-core: doctor require-ca cluster helm-core tls core-resources ## Create the lightweight local cluster
	@$(MAKE) --no-print-directory status

up: doctor require-ca cluster helm-full tls full-resources ## Create the complete local cluster
	@$(MAKE) --no-print-directory status

status: ## Show cluster nodes, releases, pods, and ingresses
	@kubectl --context "$(KUBE_CONTEXT)" get nodes
	@helm list --all-namespaces
	@kubectl --context "$(KUBE_CONTEXT)" get pods --all-namespaces
	@kubectl --context "$(KUBE_CONTEXT)" get ingress --all-namespaces 2>/dev/null || true

ports: ## Print host access details for data services
	@echo "Postgres:   kubectl --context $(KUBE_CONTEXT) -n data port-forward service/postgres-rw 5432:5432"
	@echo "ClickHouse: kubectl --context $(KUBE_CONTEXT) -n data port-forward service/clickhouse 8123:8123"
	@echo "Kafka:      kafka.k8s.localhost:9094 (broker metadata uses port 9095)"

load: ## Load IMAGE into the Kind cluster
	@test -n "$(IMAGE)" || { echo "Usage: make load IMAGE=example/app:dev"; exit 1; }
	kind load docker-image "$(IMAGE)" --name "$(CLUSTER_NAME)"

reset: ## Delete the cluster and all local cluster data (requires CONFIRM=1)
	@test "$(CONFIRM)" = "1" || { echo "This deletes the cluster and every PVC. Re-run as: make reset CONFIRM=1"; exit 1; }
	kind delete cluster --name "$(CLUSTER_NAME)"
