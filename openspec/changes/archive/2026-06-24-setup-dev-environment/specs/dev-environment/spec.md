## ADDED Requirements

### Requirement: Reproducible dependency management with UV

The project SHALL use UV as the sole project and dependency manager. A `pyproject.toml` SHALL declare the
project metadata and dependencies, and a `uv.lock` file SHALL be committed to version control so that every
environment (developer machines and CI) resolves to identical dependency versions. Dependencies MUST be added
through UV (`uv add` / `uv add --dev`) rather than edited by hand in an ad-hoc way, so that the lockfile stays
in sync.

#### Scenario: Fresh checkout produces an identical environment

- **WHEN** a developer clones the repository and runs `uv sync`
- **THEN** UV creates a `.venv` whose installed package versions match `uv.lock` exactly, without resolving or
  upgrading any dependency

#### Scenario: Adding a dependency updates the lockfile

- **WHEN** a developer runs `uv add <package>` (or `uv add --dev <package>`)
- **THEN** `pyproject.toml` and `uv.lock` are both updated and the package is installed into the project `.venv`

### Requirement: Pinned Python version

The project SHALL require Python 3.14 or newer via `requires-python = ">=3.14"` in `pyproject.toml`, and SHALL
declare the same baseline in a `.python-version` file so UV provisions a matching interpreter automatically.

#### Scenario: Interpreter is provisioned to the pinned version

- **WHEN** a developer runs `uv sync` on a machine without Python 3.14
- **THEN** UV provisions a Python 3.14+ interpreter for the project rather than failing or using an older version

#### Scenario: An older interpreter is rejected

- **WHEN** the project is run against a Python interpreter older than 3.14
- **THEN** the tooling reports that the `requires-python` constraint is not satisfied

### Requirement: Linting and formatting with Ruff

The project SHALL use Ruff as both linter and formatter, configured in `pyproject.toml`. The configuration MUST
set `line-length = 120`, enable the lint rule families `E`, `F`, `I`, `UP`, `B`, `N`, `ASYNC`, and `SIM`, and
exclude migration directories from linting. The `N` (naming) and `ASYNC` rule families exist specifically to
reinforce the project's strict naming conventions and "async everywhere" rule.

#### Scenario: Lint check passes on conforming code

- **WHEN** a developer runs `uv run ruff check`
- **THEN** Ruff evaluates the codebase against the configured rule families and exits successfully when no
  violations exist

#### Scenario: Formatting is consistent and idempotent

- **WHEN** a developer runs `uv run ruff format`
- **THEN** all Python files are formatted to the configured `line-length = 120`, and running the command again
  produces no further changes

#### Scenario: Migration paths are excluded

- **WHEN** Ruff runs over a tree that contains a `migrations/` directory
- **THEN** files under that directory are not reported as lint violations

### Requirement: Test runner with pytest

The project SHALL include pytest as a development dependency so the pure `domain/` layer can be tested without
starting any external process or framework. Running the test suite SHALL be done via `uv run pytest`.

#### Scenario: Test suite runs through UV

- **WHEN** a developer runs `uv run pytest`
- **THEN** pytest executes inside the project environment and reports the suite result (passing when no tests
  fail)

### Requirement: Static type checking with mypy

The project SHALL include mypy in strict mode as a development dependency, configured in `pyproject.toml`.
Running `uv run mypy` SHALL type-check the project. Astral's `ty` checker is explicitly recorded as a future
replacement candidate but SHALL NOT be adopted as part of this change.

#### Scenario: Type check runs in strict mode

- **WHEN** a developer runs `uv run mypy`
- **THEN** mypy type-checks the project under strict settings and reports any typing violations, exiting
  successfully when none exist

### Requirement: Canonical quality commands

The project SHALL standardize on a single, documented set of quality commands so that local development and CI
use the same entry points: `uv run ruff check`, `uv run ruff format`, `uv run pytest`, and `uv run mypy`. These
commands MUST work identically after a plain `uv sync`, with no additional global tool installation required.
The same gates SHALL also be reachable through the task runner shortcuts (see "Task runner shortcuts").

#### Scenario: All quality gates are runnable after sync

- **WHEN** a developer runs `uv sync` followed by `uv run ruff check`, `uv run ruff format --check`,
  `uv run pytest`, and `uv run mypy`
- **THEN** each command resolves its tool from the project environment and runs without requiring any
  globally-installed tooling

### Requirement: Task runner shortcuts

The project SHALL provide task runner shortcuts via poethepoet, configured under `[tool.poe.tasks]` in
`pyproject.toml` and added as a development dependency. Each individual quality gate SHALL have a named task
(`lint`, `format`, `format-check`, `type`, `test`), and a single aggregate task SHALL run every gate in
sequence using the non-mutating checks (`check` = `format-check` → `lint` → `type` → `test`), so that one
command reports the full quality status. Tasks SHALL be invoked through `uv run poe <task>` and MUST NOT
require any globally-installed tooling beyond `uv sync`.

#### Scenario: A single command runs every quality gate

- **WHEN** a developer runs `uv run poe check`
- **THEN** poethepoet runs the format check, lint, type check, and tests in sequence, reporting each step's
  result separately and failing if any gate fails

#### Scenario: Individual gates have named shortcuts

- **WHEN** a developer runs `uv run poe lint` (or `format`, `format-check`, `type`, `test`)
- **THEN** poethepoet runs exactly that gate's underlying command from the project environment
