SHELL := /bin/bash
.DEFAULT_GOAL := help

CLUSTER_NAME ?= local-dev
KUBE_CONTEXT ?= kind-$(CLUSTER_NAME)
IMAGE ?=
CONFIRM ?=

.PHONY: help doctor cluster helm-core helm-full up-core up status load reset

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

up-core: doctor cluster helm-core ## Create the lightweight local cluster
	@$(MAKE) --no-print-directory status

up: doctor cluster helm-full ## Create the complete local cluster
	@$(MAKE) --no-print-directory status

status: ## Show cluster nodes, releases, pods, and ingresses
	@kubectl --context "$(KUBE_CONTEXT)" get nodes
	@helm list --all-namespaces
	@kubectl --context "$(KUBE_CONTEXT)" get pods --all-namespaces
	@kubectl --context "$(KUBE_CONTEXT)" get ingress --all-namespaces 2>/dev/null || true

load: ## Load IMAGE into the Kind cluster
	@test -n "$(IMAGE)" || { echo "Usage: make load IMAGE=example/app:dev"; exit 1; }
	kind load docker-image "$(IMAGE)" --name "$(CLUSTER_NAME)"

reset: ## Delete the cluster and all local cluster data (requires CONFIRM=1)
	@test "$(CONFIRM)" = "1" || { echo "This deletes the cluster and every PVC. Re-run as: make reset CONFIRM=1"; exit 1; }
	kind delete cluster --name "$(CLUSTER_NAME)"
