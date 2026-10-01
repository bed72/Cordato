SHELL := /bin/zsh

.DEFAULT_GOAL := help

LERD_SITE_PATH ?= $(abspath ../../../BackEnd/PHP/Trocado)

.PHONY: help android-lan

help: ## Lista os comandos disponiveis
	@awk 'BEGIN {FS = ":.*##"; printf "Uso: make <comando>\n\nComandos:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

android-lan: ## Compartilha o backend via Lerd e configura o launch debug Android
	@if [ ! -d "$(LERD_SITE_PATH)" ]; then \
		printf 'Backend nao encontrado em %s. Informe LERD_SITE_PATH.\n' "$(LERD_SITE_PATH)" >&2; \
		exit 1; \
	fi
	@share_output=$$(cd "$(LERD_SITE_PATH)" && lerd lan:share) || exit $$?; \
	printf '%s\n' "$$share_output"; \
	if [[ "$$share_output" =~ 'http://[0-9]+(\.[0-9]+){3}:[0-9]+' ]]; then \
		base_url="$$MATCH/api/"; \
	else \
		printf 'Nao foi possivel identificar a URL LAN do Lerd.\n' >&2; \
		exit 1; \
	fi; \
	BASE_URL="$$base_url" python3 -c 'import os, pathlib, re, sys; p = pathlib.Path(".vscode/launch.json"); s = p.read_text(); start = s.find("\"name\": \"Cordato (debug)\""); end = s.find("\"name\":", start + 1); segment = s[start:end if end >= 0 else None]; pattern = r"(--dart-define=BASE_URL=)[^\"]+"; updated, count = re.subn(pattern, lambda m: m.group(1) + os.environ["BASE_URL"], segment, count=1); (start >= 0 and count == 1) or sys.exit("BASE_URL do Cordato (debug) nao encontrado em .vscode/launch.json"); p.write_text(s[:start] + updated + s[end if end >= 0 else len(s):]) if updated != segment else None'; \
	printf 'Cordato (debug) configurado com BASE_URL=%s\n' "$$base_url"
