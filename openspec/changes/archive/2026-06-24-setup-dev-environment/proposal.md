## Why

The project is still only documentation plus the OpenSpec workflow — there is no `pyproject.toml`, no
dependency manager, no linter, no test runner, and no type checker. Before a single line of domain code is
written, the project needs a reproducible Python environment and an agreed-upon set of quality gates, because
those conventions are inherited by every module (`core/` and each `features/<context>/`). Establishing them
first means the architecture's non-negotiable rules (async everywhere, strict naming, exact-decimal money)
have automated allies from line one instead of being policed only by review.

## What Changes

- Adopt **UV** as the single project & dependency manager (replaces pip/virtualenv/poetry). The project is
  initialized with a `pyproject.toml` and a committed `uv.lock` for reproducible installs.
- Pin the Python version: `requires-python = ">=3.14"` and a `.python-version` file.
- Adopt **Ruff** as both linter and formatter, configured in `pyproject.toml`:
  `line-length = 120`, lint `select = ["E","F","I","UP","B","N","ASYNC","SIM"]`, excluding migration paths.
  The `ASYNC` and `N` rule families directly reinforce the project's "async everywhere" and naming conventions.
- Add **pytest** as the test runner (dev dependency), so the pure `domain/` can be tested without spinning
  anything up.
- Add **mypy** in strict mode as the type checker (dev dependency). `ty` (Astral's checker) is recorded as a
  future swap once it reaches maturity, to keep the toolchain coherent — but it is **not** adopted now.
- Define the canonical quality commands the whole team/CI will use: `uv run ruff check`, `uv run ruff format`,
  `uv run pytest`, `uv run mypy`.

This is project bootstrap, so there is no behavior change to any domain capability — only the establishment of
the development environment and quality tooling that all future changes build on.

## Capabilities

### New Capabilities
- `dev-environment`: Defines the project's reproducible Python toolchain and quality gates — how dependencies
  are managed (UV + lockfile), which Python version is required, and how code is linted, formatted, tested, and
  type-checked, including the canonical commands used locally and in CI.

### Modified Capabilities
<!-- None. This is the first change; no existing capability's requirements change. -->

## Impact

- **New files:** `pyproject.toml`, `uv.lock`, `.python-version`.
- **Existing files:** `.gitignore` already ignores `.venv/`, `.ruff_cache/`, `.pytest_cache/`, `.mypy_cache/` —
  no change needed there. `CLAUDE.md` "Stack and commands" section can later reference these commands (follow-up,
  not part of this change).
- **Dependencies added:** `ruff`, `pytest`, `mypy` (all dev/tooling). No runtime/framework dependency is chosen
  here — FastAPI/BlackSheep and the ORM remain deferred per the architecture notes.
- **Developers & CI:** a single documented workflow (`uv sync` then `uv run <tool>`). No production runtime impact.
