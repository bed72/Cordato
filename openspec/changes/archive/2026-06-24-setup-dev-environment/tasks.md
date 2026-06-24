## 1. Project bootstrap with UV

- [x] 1.1 Run `uv init` (as a packaged/library project) to generate the initial `pyproject.toml`; remove any
      sample `hello.py`/`main.py` it scaffolds — no application code belongs in this change
- [x] 1.2 Set `requires-python = ">=3.14"` in `pyproject.toml` and create a `.python-version` file pinning `3.14`
- [x] 1.3 Run `uv sync` to create the `.venv` and the initial `uv.lock`
- [x] 1.4 Confirm `.gitignore` already excludes `.venv/`, `.ruff_cache/`, `.pytest_cache/`, `.mypy_cache/`
      (no change expected) and that `uv.lock` is NOT ignored (it must be committed)

## 2. Linting & formatting (Ruff)

- [x] 2.1 Add Ruff as a dev dependency: `uv add --dev ruff`
- [x] 2.2 Add `[tool.ruff]` to `pyproject.toml` with `line-length = 120` and `exclude = ["**/migrations/*"]`
- [x] 2.3 Add `[tool.ruff.lint]` with `select = ["E","F","I","UP","B","N","ASYNC","SIM"]`
- [x] 2.4 Verify `uv run ruff check` and `uv run ruff format` run cleanly on the (currently empty) tree

## 3. Test runner (pytest)

- [x] 3.1 Add pytest as a dev dependency: `uv add --dev pytest`
- [x] 3.2 Add minimal `[tool.pytest.ini_options]` to `pyproject.toml` (e.g. `testpaths = ["tests"]`)
- [x] 3.3 Add a trivial smoke test (e.g. `tests/test_smoke.py` asserting `True`) so `uv run pytest` exercises
      the runner; verify it passes

## 4. Static type checking (mypy)

- [x] 4.1 Add mypy as a dev dependency: `uv add --dev mypy`
- [x] 4.2 Add `[tool.mypy]` to `pyproject.toml` with strict settings (`strict = true`, `python_version = "3.14"`)
- [x] 4.3 Record `ty` as a future swap in a short comment near the mypy config (intent capture only — do not add `ty`)
- [x] 4.4 Verify `uv run mypy` runs without error on the current tree

## 5. Verify the canonical quality commands

- [x] 5.1 From a clean state, run `uv sync` then all four gates: `uv run ruff check`, `uv run ruff format --check`,
      `uv run pytest`, `uv run mypy` — confirm each resolves from the project env with no global install
- [x] 5.2 Run `/trocado:guard` (architecture-guard) over the diff to confirm no non-negotiable rule is violated

## 6. Task runner shortcuts (poethepoet)

- [x] 6.1 Add poethepoet as a dev dependency: `uv add --dev poethepoet`
- [x] 6.2 Add `[tool.poe.tasks]` to `pyproject.toml` with `lint`, `format`, `format-check`, `type`, `test`, and
      an aggregate `check = ["format-check", "lint", "type", "test"]`
- [x] 6.3 Verify `uv run poe check` runs all gates in sequence and each `uv run poe <task>` works individually
- [x] 6.4 Re-run `/trocado:guard` over the updated diff to confirm PASS
