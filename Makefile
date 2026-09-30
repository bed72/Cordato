SHELL := /bin/zsh

.DEFAULT_GOAL := help

LERD_SITE_PATH ?= $(abspath ../../../BackEnd/PHP/Trocado)

MCP_SSH_USER ?= root
# Uses the SSH host alias configured with the VPS identity key in ~/.ssh/config.
MCP_SSH_HOST ?= supabase-vps
MCP_KONG_IP ?= 172.16.2.5
MCP_LOCAL_PORT ?= 18080
MCP_REMOTE_PORT ?= 8000
MCP_ENDPOINT ?= /mcp
MCP_PROTOCOL_VERSION ?= 2025-06-18
MCP_SSH_CONNECT_TIMEOUT ?= 10
MCP_SSH_KEEPALIVE_INTERVAL ?= 15
MCP_SSH_KEEPALIVE_COUNT ?= 3
MCP_SSH_BATCH_MODE ?= no
MCP_RECONNECT_DELAY ?= 3
MCP_HEALTHCHECK_INTERVAL ?= 15
MCP_HEALTHCHECK_TIMEOUT ?= 5
MCP_TEST_CONNECT_TIMEOUT ?= 3
MCP_TEST_MAX_TIME ?= 15

# Command executed on the VPS to resolve the current Kong container IP. This avoids depending on an IP
# that changes when Dokploy recreates the container. Set it to an empty value to use MCP_KONG_IP instead.
# The default selects Kong's project bridge network instead of Dokploy's Swarm overlay network.
MCP_REMOTE_TARGET_COMMAND ?= docker ps --format '{{.Names}}\t{{.Image}}' | awk 'tolower(\$$0) ~ /kong/ { print \$$1; exit }' | xargs -r docker inspect -f '{{json .NetworkSettings.Networks}}' | jq -r 'to_entries[] | select(.value.Gateway | length > 0) | .value.IPAddress'

.PHONY: help android-lan mcp-tunnel mcp-test mcp-resolve

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

mcp-tunnel: ## Abre o tunel SSH para o MCP
	@printf '\n\033[1;36m+--------------------------------------------------+\033[0m\n' >&2
	@printf '\033[1;36m| MCP tunnel                                       |\033[0m\n' >&2
	@printf '\033[1;36m+--------------------------------------------------+\033[0m\n' >&2
	@printf '  SSH   : $(MCP_SSH_USER)@$(MCP_SSH_HOST)\n' >&2
	@printf '  Forward: 127.0.0.1:$(MCP_LOCAL_PORT) -> remote:$(MCP_REMOTE_PORT)\n' >&2
	@if [ -n "$(MCP_REMOTE_TARGET_COMMAND)" ]; then \
		printf '  Target : resolved on every reconnect\n' >&2; \
	else \
		printf '  Target : $(MCP_KONG_IP)\n' >&2; \
	fi
	@printf '  State : waiting for connection\n' >&2
	@printf '  Press Ctrl+C to stop. Reconnect delay: $(MCP_RECONNECT_DELAY)s, health check: $(MCP_HEALTHCHECK_INTERVAL)s.\n\n' >&2
	@set -u; \
	tunnel_pid=''; \
	stop_tunnel() { \
		if [ -n "$$tunnel_pid" ]; then kill "$$tunnel_pid" 2>/dev/null || true; fi; \
	}; \
	trap 'stop_tunnel; exit 130' INT TERM; \
	while true; do \
		remote_target='$(MCP_KONG_IP)'; \
		if [ -n "$(MCP_REMOTE_TARGET_COMMAND)" ]; then \
			if ! remote_target=$$(ssh -T -o BatchMode=$(MCP_SSH_BATCH_MODE) \
				-o ConnectTimeout=$(MCP_SSH_CONNECT_TIMEOUT) \
				"$(MCP_SSH_USER)@$(MCP_SSH_HOST)" \
				"$(MCP_REMOTE_TARGET_COMMAND)"); then \
				printf '  Could not resolve the remote MCP target. Retrying in $(MCP_RECONNECT_DELAY)s.\n' >&2; \
				sleep $(MCP_RECONNECT_DELAY) || exit 130; \
				continue; \
			else \
				remote_target=$$(printf '%s' "$$remote_target" | tr -d '[:space:]'); \
				if [ -z "$$remote_target" ]; then \
					printf '  Remote target resolver returned an empty address. Retrying in $(MCP_RECONNECT_DELAY)s.\n' >&2; \
					sleep $(MCP_RECONNECT_DELAY) || exit 130; \
					continue; \
				fi; \
			fi; \
		fi; \
		printf '  Connecting to remote target %s...\n' "$$remote_target" >&2; \
		restart_required=0; \
		ssh -N -T \
			-o ExitOnForwardFailure=yes \
			-o ServerAliveInterval=$(MCP_SSH_KEEPALIVE_INTERVAL) \
			-o ServerAliveCountMax=$(MCP_SSH_KEEPALIVE_COUNT) \
			-o TCPKeepAlive=yes \
			-o ConnectTimeout=$(MCP_SSH_CONNECT_TIMEOUT) \
			-o ConnectionAttempts=3 \
			-L "127.0.0.1:$(MCP_LOCAL_PORT):$$remote_target:$(MCP_REMOTE_PORT)" \
			"$(MCP_SSH_USER)@$(MCP_SSH_HOST)" & \
		tunnel_pid=$$!; \
		while kill -0 "$$tunnel_pid" 2>/dev/null; do \
			sleep $(MCP_HEALTHCHECK_INTERVAL) || { stop_tunnel; wait "$$tunnel_pid" 2>/dev/null || true; exit 130; }; \
			health_status=$$(curl -sS \
				--connect-timeout $(MCP_HEALTHCHECK_TIMEOUT) \
				--max-time $(MCP_HEALTHCHECK_TIMEOUT) \
				-o /dev/null \
				--write-out '%{http_code}' \
				"http://127.0.0.1:$(MCP_LOCAL_PORT)$(MCP_ENDPOINT)" 2>/dev/null); \
			health_curl_status=$$?; \
			if [ "$$health_curl_status" -ne 0 ] && [ "$$health_status" = 000 ]; then \
				printf '  Remote MCP target stopped responding; restarting tunnel to refresh its IP.\n' >&2; \
				restart_required=1; \
				stop_tunnel; \
				wait "$$tunnel_pid" 2>/dev/null || true; \
				break; \
			fi; \
		done; \
		if [ "$$restart_required" -eq 1 ]; then \
			wait "$$tunnel_pid" 2>/dev/null || true; \
			ssh_status=1; \
		elif kill -0 "$$tunnel_pid" 2>/dev/null; then \
			wait "$$tunnel_pid"; \
			ssh_status=$$?; \
		else \
			wait "$$tunnel_pid" 2>/dev/null || ssh_status=$$?; \
			ssh_status=$${ssh_status:-1}; \
		fi; \
		tunnel_pid=''; \
		case "$$ssh_status" in \
			130|143) exit "$$ssh_status" ;; \
		esac; \
		printf '  SSH tunnel stopped (exit %s). Retrying in $(MCP_RECONNECT_DELAY)s...\n' "$$ssh_status" >&2; \
		sleep $(MCP_RECONNECT_DELAY) || exit 130; \
	done

mcp-resolve: ## Resolve o IP atual do Kong no VPS
	@printf '  Resolving the remote MCP target on $(MCP_SSH_USER)@$(MCP_SSH_HOST)...\n' >&2
	@if [ -z "$(MCP_REMOTE_TARGET_COMMAND)" ]; then \
		printf '%s\n' '$(MCP_KONG_IP)'; \
	else \
		ssh -T -o BatchMode=$(MCP_SSH_BATCH_MODE) \
			-o ConnectTimeout=$(MCP_SSH_CONNECT_TIMEOUT) \
			"$(MCP_SSH_USER)@$(MCP_SSH_HOST)" \
			"$(MCP_REMOTE_TARGET_COMMAND)"; \
	fi

mcp-test: ## Testa a conexao local com o MCP
	@printf '\n\033[1;36m+--------------------------------------------------+\033[0m\n' >&2
	@printf '\033[1;36m| MCP connection test                              |\033[0m\n' >&2
	@printf '\033[1;36m+--------------------------------------------------+\033[0m\n' >&2
	@printf '  Target: http://127.0.0.1:$(MCP_LOCAL_PORT)$(MCP_ENDPOINT)\n' >&2
	@printf '  Action: initialize\n\n' >&2
	@tmp_dir=$$(mktemp -d); \
	trap 'rm -rf "$$tmp_dir"' EXIT; \
	http_status=$$(curl -sS \
		--connect-timeout $(MCP_TEST_CONNECT_TIMEOUT) \
		--max-time $(MCP_TEST_MAX_TIME) \
		-D "$$tmp_dir/headers" \
		-o "$$tmp_dir/body" \
		http://127.0.0.1:$(MCP_LOCAL_PORT)$(MCP_ENDPOINT) \
		-X POST \
		-H 'Content-Type: application/json' \
		-H 'Accept: application/json, text/event-stream' \
		-H 'MCP-Protocol-Version: $(MCP_PROTOCOL_VERSION)' \
		--data-raw '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"$(MCP_PROTOCOL_VERSION)","capabilities":{"elicitation":{}},"clientInfo":{"name":"trocado-mcp-check","version":"1.0.0"}}}' \
		2>"$$tmp_dir/curl-error" \
		--write-out '%{http_code}'); \
	curl_status=$$?; \
	if [ $$curl_status -ne 0 ] && [ $$curl_status -ne 28 ]; then \
		printf '\n\033[1;31m  Result: FAILED\033[0m\n' >&2; \
		printf '  Check that the MCP tunnel is running with: make mcp-tunnel\n' >&2; \
		printf '  curl exit code: %s\n\n' "$$curl_status" >&2; \
		if [ $$curl_status -eq 56 ]; then \
			printf '  The local SSH forward is open, but the remote MCP target reset the connection.\n' >&2; \
			printf '  Restart the tunnel and verify its target with: make mcp-resolve\n\n' >&2; \
		fi; \
		[ ! -s "$$tmp_dir/curl-error" ] || while IFS= read -r line; do printf '  %s\n' "$$line" >&2; done < "$$tmp_dir/curl-error"; \
		exit $$curl_status; \
	fi; \
	if [[ "$$http_status" != 2* ]]; then \
		printf '\n\033[1;31m  Result: FAILED\033[0m\n' >&2; \
		printf '  MCP returned HTTP %s\n\n' "$$http_status" >&2; \
		exit 1; \
	fi; \
	if [ ! -s "$$tmp_dir/body" ]; then \
		printf '\n\033[1;31m  Result: FAILED\033[0m\n' >&2; \
		printf '  MCP returned HTTP %s but no initialize payload.\n\n' "$$http_status" >&2; \
		exit 1; \
	fi; \
	if [[ "$$http_status" == 2* ]]; then \
		printf '\033[1;32m  Result: HTTP %s (OK)\033[0m\n' "$$http_status" >&2; \
		if [ $$curl_status -eq 28 ]; then \
			printf '  Stream stayed open until the test timeout; the initialize response was received.\n' >&2; \
		fi; \
	fi; \
	printf '\n  Headers:\n' >&2; \
	while IFS= read -r line; do \
		line=$${line%$$'\r'}; \
		[ -n "$$line" ] && printf '    %s\n' "$$line" >&2; \
	done < "$$tmp_dir/headers"; \
	printf '\n  Body:\n' >&2; \
	if command -v jq >/dev/null 2>&1 && jq empty "$$tmp_dir/body" >/dev/null 2>&1; then \
		jq . "$$tmp_dir/body" | while IFS= read -r line; do printf '    %s\n' "$$line" >&2; done; \
	else \
		while IFS= read -r line; do printf '    %s\n' "$$line" >&2; done < "$$tmp_dir/body"; \
	fi; \
	printf '\n' >&2
