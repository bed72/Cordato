# Cordato — task runner
# Thin wrapper over ./gradlew. Run `make` or `make help` for the menu.

GRADLE := ./gradlew

# Args:
#   CLASS  fully-qualified (or wildcard) test class for `make test-class`
#          e.g. make test-class CLASS=com.bed.cordato.features.identity.SignUpUseCaseTest
CLASS ?=

.DEFAULT_GOAL := help

## ─── Help ────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show this menu
	@echo "Cordato — available targets:"
	@echo
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Examples:"
	@echo "  make test"
	@echo "  make test-class CLASS=com.bed.cordato.features.identity.SignUpUseCaseTest"
	@echo "  make test-class CLASS='com.bed.cordato.features.identity.*'"

## ─── Build & test ────────────────────────────────────────────────────────

.PHONY: build
build: ## Compile and assemble everything (runs tests)
	$(GRADLE) build

.PHONY: compile
compile: ## Compile main + test sources without running tests
	$(GRADLE) testClasses

.PHONY: test
test: ## Run all tests
	$(GRADLE) test

.PHONY: test-class
test-class: ## Run a single test class (CLASS=<fqcn or wildcard>)
	@test -n "$(CLASS)" || { echo "error: set CLASS=<fully-qualified test class>"; exit 1; }
	$(GRADLE) test --tests "$(CLASS)"

.PHONY: check
check: ## Run the full verification suite (tests + Konsist architecture checks)
	$(GRADLE) check

## ─── Run ───────────────────────────────────────────────────────────────────

# Boots the embedded HTTP server. `Main` migrates the DB before opening the port, so the local
# PostgreSQL must be up — `db-up` is a prerequisite here so `make run` is one command. Once it prints
# "Cordato started on http://localhost:8080", the Swagger UI is at /swagger-ui/index.html.
.PHONY: run
run: db-up valkey-up ## Start the app (brings up Postgres + Valkey, then serves on http://localhost:8080)
	$(GRADLE) run

## ─── Local infrastructure (Docker) ────────────────────────────────────────

# Local dev runs against PostgreSQL + Valkey from compose.yml. Docker must be running.
# Credentials come from a git-ignored .env (created from .env.example on first `db-up`/`valkey-up`).
# Note: the test suite provisions its own throwaway containers via Testcontainers — these
# targets are only for running the app locally, not for `make test`.

.env:
	cp .env.example .env
	@echo "created .env from .env.example — adjust credentials if needed"

.PHONY: db-up
db-up: .env ## Start the local PostgreSQL (docker compose up -d)
	docker compose up -d postgres

.PHONY: db-down
db-down: ## Stop the local PostgreSQL (data kept in the named volume)
	docker compose stop postgres

.PHONY: db-reset
db-reset: ## Stop the local PostgreSQL and delete its data volume
	docker compose rm -f -s -v postgres

.PHONY: db-logs
db-logs: ## Tail the local PostgreSQL logs
	docker compose logs -f postgres

.PHONY: valkey-up
valkey-up: .env ## Start the local Valkey cache (docker compose up -d)
	docker compose up -d valkey

.PHONY: valkey-down
valkey-down: ## Stop the local Valkey cache (data kept in the named volume)
	docker compose stop valkey

.PHONY: valkey-reset
valkey-reset: ## Stop the local Valkey cache and delete its data volume
	docker compose rm -f -s -v valkey

.PHONY: valkey-logs
valkey-logs: ## Tail the local Valkey logs
	docker compose logs -f valkey

## ─── Housekeeping ────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Delete build outputs
	$(GRADLE) clean

.PHONY: tasks
tasks: ## List all Gradle tasks
	$(GRADLE) tasks --all
