## Why

A HTTP edge está viva (Litestar, autenticação completa, criação de budget) e os fluxos HTTP já estão cobertos por integration tests via `litestar.testing.TestClient` (`tests/identity/integrations/test_authentication_http.py`, `tests/budgeting/integrations/test_create_budget_http_integration.py`). O que ainda não existe é uma baseline de throughput: quando o ORM chegar não saberemos se introduziu regressão de latência, e não temos como quantificar o comportamento sob carga. Este change formaliza o padrão existente de integration tests (via spec) e adiciona a camada de load tests com Locust.

## What Changes

- Formalizar em spec o padrão de HTTP integration tests com `litestar.testing.TestClient` já em uso — cobrindo isolamento via `build()`, verificação do envelope de erro unificado, e persistência intra-teste no repositório in-memory.
- Adicionar Locust como dependência de dev e um `locustfile.py` na raiz definindo cenários de carga para os fluxos de autenticação e criação de budget (sign-up → sign-in → create budget), com métricas de RPS, P95 e P99.
- Adicionar o comando `poe stress` ao `pyproject.toml` para rodar o Locust headless em CI.

## Capabilities

### New Capabilities

- `http-integration-tests`: formaliza o padrão de testes end-to-end via TestClient contra `build()` — status HTTP, envelope de erro unificado, persistência entre requests no mesmo run, isolamento entre testes (cada `with TestClient(build())` parte de um estado zerado).
- `load-tests`: cenários Locust modelando usuários virtuais autenticados fazendo operações reais; baseline de RPS e latência (P95/P99) antes do ORM.

### Modified Capabilities

- `dev-environment`: adição de `locust` como dependência de dev e do comando `poe stress` ao conjunto de comandos.

## Impact

- **Novos arquivos**: `locustfile.py` (raiz).
- **Arquivos existentes com testes**: `tests/identity/integrations/`, `tests/budgeting/integrations/` — já existem, spec apenas os formaliza.
- **Dependências**: `locust` (dev). Nenhuma dependência de runtime adicionada.
- **`pyproject.toml`**: novo task `stress` no `[tool.poe.tasks]`.
- Nenhuma mudança em `domain/`, `application/` ou nos adapters existentes.
