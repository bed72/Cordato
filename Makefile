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

## ─── Local database (Docker) ─────────────────────────────────────────────

# Local dev runs against PostgreSQL from compose.yml. Docker must be running.
# Credentials come from a git-ignored .env (created from .env.example on first `db-up`).
# Note: the test suite provisions its own PostgreSQL via Testcontainers — these
# targets are only for running the app locally, not for `make test`.

.env:
	cp .env.example .env
	@echo "created .env from .env.example — adjust credentials if needed"

.PHONY: db-up
db-up: .env ## Start the local PostgreSQL (docker compose up -d)
	docker compose up -d

.PHONY: db-down
db-down: ## Stop the local PostgreSQL (data kept in the named volume)
	docker compose down

.PHONY: db-reset
db-reset: ## Stop the local PostgreSQL and delete its data volume
	docker compose down -v

.PHONY: db-logs
db-logs: ## Tail the local PostgreSQL logs
	docker compose logs -f postgres

## ─── Housekeeping ────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Delete build outputs
	$(GRADLE) clean

.PHONY: tasks
tasks: ## List all Gradle tasks
	$(GRADLE) tasks --all
