# =============================================================================
# SimpleCommerce — Makefile
# =============================================================================
# Industrial-grade Makefile for Go workspace-based microservice monorepo.
# Auto-discovers services from go.work, supports per-service operations,
# CI/CD integration, Docker BuildKit caching, and self-documenting help.
# =============================================================================

# ---------------------------------------------------------------------------
# Project Metadata
# ---------------------------------------------------------------------------
APP_NAME        := simplecommerce
GO_VERSION      := 1.26.2
GIT_COMMIT      := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME      := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
VERSION         := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
GO_LDFLAGS      := -ldflags="-X main.Version=$(VERSION) -X main.Commit=$(GIT_COMMIT) -X main.BuildTime=$(BUILD_TIME)"

# ---------------------------------------------------------------------------
# Service Discovery — auto-detect from go.work
# ---------------------------------------------------------------------------
SERVICES        := $(shell grep -E '^\s+\./services/' go.work | sed 's|.*/services/||' | sort)
SHARED_DIR      := ./shared
BIN_DIR         := ./bin
TEST_RESULTS_DIR := ./test-results

# All workspace modules (shared + services) for top-level operations
WORKSPACE_MODULES := $(SHARED_DIR) $(addprefix services/, $(SERVICES))

# ---------------------------------------------------------------------------
# Tooling
# ---------------------------------------------------------------------------
GOLANGCI_LINT   := golangci-lint
GO              := go

# ---------------------------------------------------------------------------
# Colors for terminal output
# ---------------------------------------------------------------------------
COLOR_RESET     := \033[0m
COLOR_BOLD      := \033[1m
COLOR_GREEN     := \033[32m
COLOR_YELLOW    := \033[33m
COLOR_CYAN      := \033[36m

# =============================================================================
# Targets
# =============================================================================

.PHONY: help info
.PHONY: build build-all build/% clean
.PHONY: test test-all test/% test-coverage test-coverage/% test-verbose
.PHONY: lint lint-all lint/%
.PHONY: fmt
.PHONY: tidy tidy-all tidy/% deps-update
.PHONY: docker-build/% docker-build-all docker-push/%
.PHONY: dev/% dev-up dev-down dev-logs
.PHONY: check
.PHONY: ci-lint ci-test ci-build

# ---------------------------------------------------------------------------
# Help & Info
# ---------------------------------------------------------------------------

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(COLOR_CYAN)%-30s$(COLOR_RESET) %s\n", $$1, $$2}'

info: ## Show project metadata
	@echo "$(COLOR_BOLD)Project:$(COLOR_RESET)       $(APP_NAME)"
	@echo "$(COLOR_BOLD)Go version:$(COLOR_RESET)    $(GO_VERSION)"
	@echo "$(COLOR_BOLD)Version:$(COLOR_RESET)       $(VERSION)"
	@echo "$(COLOR_BOLD)Git commit:$(COLOR_RESET)    $(GIT_COMMIT)"
	@echo "$(COLOR_BOLD)Build time:$(COLOR_RESET)    $(BUILD_TIME)"
	@echo "$(COLOR_BOLD)Services:$(COLOR_RESET)"
	@for svc in $(SERVICES); do \
		printf "  - %s\n" $$svc; \
	done

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build-all: $(addprefix build/, $(SERVICES)) ## Build all service binaries

build/%: ## Build binary for a specific service (e.g., make build/user-service)
	$(eval SVC := $(word 2, $(subst /, ,$@)))
	@printf "$(COLOR_YELLOW)Building $(SVC)...$(COLOR_RESET)\n"
	@mkdir -p $(BIN_DIR)
	(cd services/$(SVC) && $(GO) build $(GO_LDFLAGS) -o $(CURDIR)/$(BIN_DIR)/$(SVC) ./cmd/server/) || exit 1
	@printf "$(COLOR_GREEN)✓ $(SVC) built → $(BIN_DIR)/$(SVC)$(COLOR_RESET)\n"

build: ## Build all packages across all workspace modules
	@for mod in $(WORKSPACE_MODULES); do \
		printf "$(COLOR_YELLOW)Building %s...$(COLOR_RESET)\n" $$mod; \
		(cd $$mod && $(GO) build ./...) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ All modules built$(COLOR_RESET)\n"

clean: ## Remove build artifacts and test results
	@printf "$(COLOR_YELLOW)Cleaning...$(COLOR_RESET)\n"
	rm -rf $(BIN_DIR) $(TEST_RESULTS_DIR) coverage.out coverage.html
	@printf "$(COLOR_GREEN)✓ Cleaned$(COLOR_RESET)\n"

# ---------------------------------------------------------------------------
# Test
# ---------------------------------------------------------------------------

test-all: $(addprefix test/, $(SERVICES)) ## Test all services

test/%: ## Test a specific service (e.g., make test/user-service)
	$(eval SVC := $(word 2, $(subst /, ,$@)))
	@printf "$(COLOR_YELLOW)Testing $(SVC)...$(COLOR_RESET)\n"
	(cd services/$(SVC) && $(GO) test -race -count=1 ./...) || exit 1

test: ## Test all modules with race detector
	@for mod in $(WORKSPACE_MODULES); do \
		printf "$(COLOR_YELLOW)Testing %s...$(COLOR_RESET)\n" $$mod; \
		(cd $$mod && $(GO) test -race -count=1 ./...) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ All tests passed$(COLOR_RESET)\n"

test-verbose: ## Test all modules with verbose output
	@for mod in $(WORKSPACE_MODULES); do \
		printf "$(COLOR_YELLOW)Testing %s...$(COLOR_RESET)\n" $$mod; \
		(cd $$mod && $(GO) test -race -count=1 -v ./...) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ All tests passed$(COLOR_RESET)\n"

test-coverage: ## Generate full coverage report
	@printf "$(COLOR_YELLOW)Generating coverage report...$(COLOR_RESET)\n"
	@for mod in $(WORKSPACE_MODULES); do \
		(cd $$mod && $(GO) test -race -count=1 -coverprofile=coverage.out ./...) || exit 1; \
	done
	$(GO) tool cover -html=coverage.out -o coverage.html
	@printf "$(COLOR_GREEN)✓ Coverage report → coverage.html$(COLOR_RESET)\n"

test-coverage/%: ## Generate coverage report for a specific service
	$(eval SVC := $(word 2, $(subst /, ,$@)))
	@printf "$(COLOR_YELLOW)Generating coverage report for $(SVC)...$(COLOR_RESET)\n"
	(cd services/$(SVC) && $(GO) test -race -count=1 -coverprofile=coverage.out ./... && $(GO) tool cover -html=coverage.out -o coverage.html) || exit 1
	@printf "$(COLOR_GREEN)✓ Coverage report → services/$(SVC)/coverage.html$(COLOR_RESET)\n"

# ---------------------------------------------------------------------------
# Lint
# ---------------------------------------------------------------------------

lint-all: $(addprefix lint/, $(SERVICES)) ## Lint all services

lint/%: ## Lint a specific service (e.g., make lint/user-service)
	$(eval SVC := $(word 2, $(subst /, ,$@)))
	@printf "$(COLOR_YELLOW)Linting $(SVC)...$(COLOR_RESET)\n"
	(cd services/$(SVC) && $(GOLANGCI_LINT) run ./...) || exit 1

lint: ## Lint all modules
	@for mod in $(WORKSPACE_MODULES); do \
		printf "$(COLOR_YELLOW)Linting %s...$(COLOR_RESET)\n" $$mod; \
		(cd $$mod && $(GOLANGCI_LINT) run ./...) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ All modules linted$(COLOR_RESET)\n"

# ---------------------------------------------------------------------------
# Format
# ---------------------------------------------------------------------------

fmt: ## Format all Go code across all workspace modules
	@for mod in $(WORKSPACE_MODULES); do \
		printf "$(COLOR_YELLOW)Formatting %s...$(COLOR_RESET)\n" $$mod; \
		(cd $$mod && $(GO) fmt ./...) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ All modules formatted$(COLOR_RESET)\n"

# ---------------------------------------------------------------------------
# Dependency Management
# ---------------------------------------------------------------------------

tidy-all: $(addprefix tidy/, $(SERVICES)) ## Tidy all services

tidy/%: ## Tidy dependencies for a specific service
	$(eval SVC := $(word 2, $(subst /, ,$@)))
	@printf "$(COLOR_YELLOW)Tidying $(SVC)...$(COLOR_RESET)\n"
	(cd services/$(SVC) && $(GO) mod tidy) || exit 1

tidy: ## Sync workspace and tidy all modules
	@printf "$(COLOR_YELLOW)Syncing workspace...$(COLOR_RESET)\n"
	$(GO) work sync
	@printf "$(COLOR_YELLOW)Tidying shared module...$(COLOR_RESET)\n"
	(cd $(SHARED_DIR) && $(GO) mod tidy) || exit 1
	@printf "$(COLOR_YELLOW)Tidying all services...$(COLOR_RESET)\n"
	@for svc in $(SERVICES); do \
		printf "  - Tidying %s...\n" $$svc; \
		(cd services/$$svc && $(GO) mod tidy) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ All modules tidied$(COLOR_RESET)\n"

deps-update: ## Update all dependencies to latest patch/minor versions
	@printf "$(COLOR_YELLOW)Updating shared module dependencies...$(COLOR_RESET)\n"
	(cd $(SHARED_DIR) && $(GO) get -u ./... && $(GO) mod tidy) || exit 1
	@for svc in $(SERVICES); do \
		printf "  - Updating %s...\n" $$svc; \
		(cd services/$$svc && $(GO) get -u ./... && $(GO) mod tidy) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ All dependencies updated$(COLOR_RESET)\n"

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------

docker-build-all: $(addprefix docker-build/, $(SERVICES)) ## Build Docker images for all services

docker-build/%: ## Build Docker image for a service using BuildKit cache (e.g., make docker-build/user-service)
	$(eval SVC := $(word 2, $(subst /, ,$@)))
	@printf "$(COLOR_YELLOW)Building Docker image for $(SVC)...$(COLOR_RESET)\n"
	DOCKER_BUILDKIT=1 docker build \
		--cache-from type=local,src=.cache/$(SVC) \
		--cache-to type=local,dest=.cache/$(SVC),mode=max \
		-t $(APP_NAME)/$(SVC):$(VERSION) \
		-t $(APP_NAME)/$(SVC):latest \
		-f services/$(SVC)/Dockerfile \
		.
	@printf "$(COLOR_GREEN)✓ $(APP_NAME)/$(SVC):$(VERSION) built$(COLOR_RESET)\n"

docker-push/%: ## Push Docker image for a service to registry (e.g., make docker-push/user-service)
	$(eval SVC := $(word 2, $(subst /, ,$@)))
	@printf "$(COLOR_YELLOW)Pushing $(APP_NAME)/$(SVC):$(VERSION)...$(COLOR_RESET)\n"
	docker push $(APP_NAME)/$(SVC):$(VERSION)
	docker push $(APP_NAME)/$(SVC):latest
	@printf "$(COLOR_GREEN)✓ $(APP_NAME)/$(SVC) pushed$(COLOR_RESET)\n"

# ---------------------------------------------------------------------------
# Development
# ---------------------------------------------------------------------------

dev/%: ## Run a single service locally (e.g., make dev/user-service)
	$(eval SVC := $(word 2, $(subst /, ,$@)))
	@printf "$(COLOR_YELLOW)Starting $(SVC) locally...$(COLOR_RESET)\n"
	(cd services/$(SVC) && $(GO) run ./cmd/server/) || exit 1

dev-up: ## Start all development dependencies (DB, message broker, etc.)
	@printf "$(COLOR_YELLOW)Starting development dependencies...$(COLOR_RESET)\n"
	docker compose -f infrastructure/docker-compose.dev.yaml up -d
	@printf "$(COLOR_GREEN)✓ Development dependencies started$(COLOR_RESET)\n"

dev-down: ## Stop all development dependencies
	@printf "$(COLOR_YELLOW)Stopping development dependencies...$(COLOR_RESET)\n"
	docker compose -f infrastructure/docker-compose.dev.yaml down
	@printf "$(COLOR_GREEN)✓ Development dependencies stopped$(COLOR_RESET)\n"

dev-logs: ## Tail logs from development dependencies
	docker compose -f infrastructure/docker-compose.dev.yaml logs -f

# ---------------------------------------------------------------------------
# CI/CD
# ---------------------------------------------------------------------------

ci-lint: ## Run linter with CI-optimized settings across all modules
	@for mod in $(WORKSPACE_MODULES); do \
		printf "Linting %s...\n" $$mod; \
		(cd $$mod && $(GOLANGCI_LINT) run --out-format=colored-line-number --timeout=10m ./...) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ CI lint passed$(COLOR_RESET)\n"

ci-test: ## Run tests with JSON output for CI
	@mkdir -p $(TEST_RESULTS_DIR)
	@> $(TEST_RESULTS_DIR)/output.json
	@for mod in $(WORKSPACE_MODULES); do \
		printf "Testing %s...\n" $$mod; \
		(cd $$mod && $(GO) test -race -count=1 -json ./... >> $(CURDIR)/$(TEST_RESULTS_DIR)/output.json) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ CI tests passed$(COLOR_RESET)\n"

ci-build: ## Build all binaries for CI
	@mkdir -p $(BIN_DIR)
	@for svc in $(SERVICES); do \
		printf "Building %s...\n" $$svc; \
		(cd services/$$svc && $(GO) build $(GO_LDFLAGS) -o $(CURDIR)/$(BIN_DIR)/$$svc ./cmd/server/) || exit 1; \
	done
	@printf "$(COLOR_GREEN)✓ All binaries built → $(BIN_DIR)/$(COLOR_RESET)\n"

# ---------------------------------------------------------------------------
# Pre-Commit Check
# ---------------------------------------------------------------------------

check: tidy fmt lint test ## Run all pre-commit checks (tidy → fmt → lint → test)
	@echo "$(COLOR_GREEN)$(COLOR_BOLD)✅ All checks passed$(COLOR_RESET)"
