.DEFAULT_GOAL := help
SHELL := /bin/sh
BACKEND_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ENV_FILE ?= .env.development.local
REQUEST ?= authentication/01-login.bru

.PHONY: help run test test-race vet check test-unit test-integration test-e2e bruno-version bruno-check bruno bruno-upload test-bruno

help:
	@printf '%s\n' \
	  'make run                  Servidor local em 127.0.0.1:8091' \
	  'make test                 Suíte Go sem portas' \
	  'make test-race            Race detector' \
	  'make vet                  Análise Go' \
	  'make check                Go, Bruno offline e verificações shell' \
	  'make bruno                Login local pela CLI' \
	  'make bruno-upload         Login e upload do AUDIO_FILE privado' \
	  'make bruno-check          Validação offline das duas requests' \
	  'make test-bruno           E2E local com dados descartáveis'

run:
	@cd "$(BACKEND_DIR)" && sh tool/with_env.sh "$(ENV_FILE)" sh tool/run_local.sh

test:
	@cd "$(BACKEND_DIR)" && go test -count=1 ./...

test-unit:
	@cd "$(BACKEND_DIR)" && go test -count=1 ./internal/...

test-integration:
	@cd "$(BACKEND_DIR)" && go test -count=1 ./tests/integration/...

test-race:
	@cd "$(BACKEND_DIR)" && go test -race ./...

vet:
	@cd "$(BACKEND_DIR)" && go vet ./...

check:
	@$(MAKE) --no-print-directory -C "$(BACKEND_DIR)" test
	@$(MAKE) --no-print-directory -C "$(BACKEND_DIR)" test-race
	@$(MAKE) --no-print-directory -C "$(BACKEND_DIR)" vet
	@$(MAKE) --no-print-directory -C "$(BACKEND_DIR)" bruno-check
	@cd "$(BACKEND_DIR)" && sh -n tool/with_env.sh tool/run_local.sh tool/run_bruno.sh docker/entrypoint.sh && git diff --check
	@cd "$(BACKEND_DIR)" && shellcheck -e SC1090 tool/with_env.sh tool/run_local.sh tool/run_bruno.sh

test-e2e:
	@cd "$(BACKEND_DIR)" && CORDATO_HTTP_SMOKE=1 go test -count=1 -run '^TestLocalServerLifecycle$$' -v ./tests/e2e/server

bruno-version:
	@bru --version

bruno-check:
	@cd "$(BACKEND_DIR)" && node tool/check_bruno.cjs "$$(command -v bru)"
	@cd "$(BACKEND_DIR)" && node --test tool/*.test.cjs

bruno:
	@cd "$(BACKEND_DIR)" && sh tool/run_bruno.sh "$(REQUEST)"

bruno-upload:
	@cd "$(BACKEND_DIR)" && node tool/run_bruno_upload.cjs

test-bruno:
	@cd "$(BACKEND_DIR)" && CORDATO_HTTP_SMOKE=1 CORDATO_BRUNO_SMOKE=1 go test -count=1 -run '^TestLocalServerLifecycle$$' -v ./tests/e2e/server
