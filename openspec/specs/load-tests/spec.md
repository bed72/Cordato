# load-tests Specification

## Purpose

Define the convention for load/stress testing using Locust: scenario structure, authentication flow,
headless execution via `poe stress`, and baseline tracking as a pre-ORM reference.

## Requirements

### Requirement: Cenários de carga em Python via Locust

A aplicação SHALL possuir cenários de load testing definidos em `tests/stress/` usando Locust. Os cenários
MUST ser escritos em Python puro (subclasse de `HttpUser`) e MUST modelar fluxos reais da aplicação — não
endpoints isolados. Os cenários MUST cobrir ao menos o fluxo autenticado: sign-up (ou sign-in em `on_start`)
seguido de criação de budget. Cada usuário virtual MUST carregar o token de sessão obtido no `on_start` e
reutilizá-lo nas tasks subsequentes via header `Authorization: Bearer <token>`.

Os arquivos de stress seguem a convenção `tests/stress/test_<flow>.py`, cada um contendo uma classe
`Test<Flow>` (subclasse de `HttpUser`) — **não é uma classe de teste pytest**. Um `locustfile.py` na raiz
do projeto serve como entry point do Locust e importa os cenários de `tests/stress/`.

#### Scenario: Usuário virtual obtém token no on_start

- **WHEN** o Locust inicia um usuário virtual
- **THEN** o `on_start` faz sign-up (ou sign-in) e armazena o token retornado no objeto do usuário, sem
  falhar com exceção — um `on_start` que falha aborta o usuário antes das tasks

#### Scenario: Tasks usam o token armazenado

- **WHEN** uma task como `create_budget` é executada por um usuário virtual
- **THEN** o request inclui `Authorization: Bearer <token>` com o token obtido no `on_start`, e o Locust
  registra o resultado (sucesso ou falha HTTP) nas suas métricas

### Requirement: Comando poe stress para execução headless

O projeto SHALL expor um task `stress` via poethepoet que execute o Locust em modo headless contra o
servidor local. O comando MUST apontar para `http://127.0.0.1:8000` e usar parâmetros que produzam uma
baseline representativa: ao menos 50 usuários virtuais, ramp-up de 5 usuários por segundo, por ao menos
60 segundos. O comando MUST ser invocável via `uv run poe stress` sem nenhuma ferramenta global além de
`uv sync`. O servidor da aplicação MUST estar rodando separadamente (`uv run poe serve`) antes de `poe stress`
ser invocado — o comando de stress não sobe o servidor.

#### Scenario: poe stress roda o Locust headless

- **WHEN** o servidor está rodando em `http://127.0.0.1:8000` e o desenvolvedor executa `uv run poe stress`
- **THEN** o Locust inicia em modo headless, rampa até os usuários configurados, executa as tasks pelos
  segundos configurados, imprime o sumário de RPS e latência (P50, P95, P99) no terminal, e encerra

#### Scenario: poe stress falha com conexão recusada se o servidor não está rodando

- **WHEN** o desenvolvedor executa `uv run poe stress` sem o servidor ativo
- **THEN** o Locust reporta erro de conexão e encerra com código não-zero

### Requirement: Métricas de baseline registradas como pré-ORM

Os resultados do `poe stress` contra o app in-memory SHALL ser tratados como baseline pré-ORM — uma
referência de comparação, não um SLA de produção. O `locustfile.py` MUST registrar explicitamente (via
comentário ou docstring) que os números são obtidos com repositórios in-memory e devem ser reestabelecidos
quando o ORM chegar.

#### Scenario: Baseline é identificada como pré-ORM

- **WHEN** um desenvolvedor lê o locustfile.py
- **THEN** existe um comentário ou docstring explícito identificando que a baseline é pré-ORM e será
  revisitada quando o ORM substituir os repositórios in-memory
