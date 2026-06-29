## 1. Dependência e comando

- [x] 1.1 Adicionar `locust` como dependência de dev: `uv add --dev locust`
- [x] 1.2 Adicionar o task `stress` em `[tool.poe.tasks]` no `pyproject.toml`: `locust --host http://127.0.0.1:8000 --headless -u 50 -r 5 -t 60s`
- [x] 1.3 Verificar que `uv run poe stress --help` resolve o Locust sem instalação global

## 2. locustfile.py

- [x] 2.1 Criar `locustfile.py` na raiz com um comentário de cabeçalho identificando que a baseline é pré-ORM
- [x] 2.2 Implementar `AuthenticatedUser(HttpUser)` com `wait_time = between(0.5, 2)` e `on_start` que faz sign-up e armazena o token
- [x] 2.3 Implementar o task `@task create_budget` que usa o token armazenado no header `Authorization: Bearer`
- [x] 2.4 Verificar que `uv run locust --list` lista o `AuthenticatedUser` sem erros de importação

## 3. Verificação de ponta a ponta

- [x] 3.1 Subir o servidor com `uv run poe serve` e rodar `uv run poe stress` — confirmar que o Locust completa os 60s e imprime o sumário de RPS/latência sem falhas HTTP
- [x] 3.2 Confirmar que `uv run poe check` (quality gate) passa sem incluir nem depender do Locust
