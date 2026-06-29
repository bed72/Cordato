## MODIFIED Requirements

### Requirement: Task runner shortcuts

The project SHALL provide task runner shortcuts via poethepoet, configured under `[tool.poe.tasks]` in
`pyproject.toml` and added as a development dependency. Each individual quality gate SHALL have a named task
(`lint`, `format`, `format-check`, `type`, `test`), and a single aggregate task SHALL run every gate in
sequence using the non-mutating checks (`check` = `format-check` → `lint` → `type` → `test`), so that one
command reports the full quality status. Tasks SHALL be invoked through `uv run poe <task>` and MUST NOT
require any globally-installed tooling beyond `uv sync`.

A `stress` task SHALL be available as `uv run poe stress`, executando o Locust em modo headless contra
`http://127.0.0.1:8000`. O task `stress` MUST NOT fazer parte do `check` aggregate — é opt-in, não um
gate obrigatório de CI.

#### Scenario: A single command runs every quality gate

- **WHEN** a developer runs `uv run poe check`
- **THEN** poethepoet runs the format check, lint, type check, and tests in sequence, reporting each step's
  result separately and failing if any gate fails

#### Scenario: Individual gates have named shortcuts

- **WHEN** a developer runs `uv run poe lint` (or `format`, `format-check`, `type`, `test`)
- **THEN** poethepoet runs exactly that gate's underlying command from the project environment

#### Scenario: poe stress executa o Locust headless

- **WHEN** o servidor está rodando em `http://127.0.0.1:8000` e o desenvolvedor executa `uv run poe stress`
- **THEN** poethepoet executa o Locust headless a partir do `locustfile.py` da raiz, sem exigir instalação
  global do Locust além de `uv sync`
