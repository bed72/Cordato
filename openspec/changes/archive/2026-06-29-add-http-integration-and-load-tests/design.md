## Context

A HTTP edge (Litestar) está viva com autenticação completa e criação de budget. Integration tests via
`litestar.testing.TestClient` já existem em `tests/identity/integrations/test_authentication_http.py` e
`tests/budgeting/integrations/test_create_budget_http_integration.py`, cobrindo os fluxos críticos contra o
app real (`build()`). O que falta é: (a) formalizar o padrão em spec, e (b) adicionar load testing com Locust
para estabelecer uma baseline antes do ORM chegar.

## Goals / Non-Goals

**Goals:**
- Documentar em spec o padrão de HTTP integration tests já em uso, para que novos fluxos HTTP saibam como devem ser testados.
- Adicionar Locust como camada de load testing, com cenários Python que espelham os fluxos reais de autenticação e budget.
- Expor um único `poe stress` para rodar o Locust headless em CI, sem exigir ferramentas globais além de `uv sync`.

**Non-Goals:**
- Não ampliar a cobertura de integration tests existentes (os testes já cobrem os cenários relevantes).
- Não adicionar distributed load testing (Locust master/worker) — cenário single-node é suficiente nesta fase.
- Não integrar métricas de load ao CI de qualidade (`poe check`) — stress é opt-in, não um gate obrigatório.
- Não introduzir fixtures de pytest para os integration tests (o padrão `with TestClient(build())` já provê isolamento sem plugin adicional).

## Decisions

### `locustfile.py` na raiz, não dentro de `tests/`

Locust não é pytest. Seus cenários não são descobertos por pytest e não devem aparecer no `poe test`. Colocá-lo
na raiz evita confusão com o test runner e é o padrão adotado pela comunidade Locust. Uma pasta `load_tests/`
seria over-engineering para um único arquivo neste estágio.

### Locust como dependência de dev, não runtime

`locust` pertence ao mesmo grupo que `pytest` e `mypy` — ferramentas de qualidade, não requisitos do servidor.
`uv add --dev locust` mantém o grupo correto sem inflar o ambiente de produção.

### `poe stress` chama o servidor real separado (não `TestClient`)

O Locust é um cliente HTTP que faz requests contra um servidor real. O fluxo correto é:
1. `uv run poe serve` (ou `uvicorn`) em um terminal.
2. `uv run poe stress` em outro.

O `poe stress` fica configurado como `locust --host http://127.0.0.1:8000 --headless -u 50 -r 5 -t 60s`, que
representa 50 usuários virtuais, ramp-up de 5/s, por 60 segundos — valores suficientes para uma baseline sem
sobrecarregar um ambiente de dev. Parâmetros são sobrescrevíveis via CLI.

### Padrão de isolamento nos integration tests: `with TestClient(build())`

Cada teste (ou cada `with` block) instancia um app fresco via `build()`. Repositórios in-memory são
singletons do app — criados no factory, novos por `build()` — então dois testes nunca compartilham estado.
Testes que exercitam persistência entre requests (ex: sign-up seguido de sign-in) fazem ambas as calls
dentro do mesmo `with` block. Este padrão já está em uso e não requer mudanças.

## Risks / Trade-offs

- **Locust requer servidor rodando** → `poe stress` falhará com connection refused se o app não estiver em pé. Mitigação: documentar na spec que `poe serve` deve estar ativo antes.
- **Baseline sem ORM pode dar falsa confiança** → os números em memória serão muito melhores que com Postgres. Mitigação: a spec registra que os números são pré-ORM e devem ser reestabelecidos quando o ORM chegar.
- **`locust` adiciona ~15 dependências transitivas** → aceitável para uma dependência de dev; não impacta o runtime.
