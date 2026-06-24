## Context

The repository currently contains only documentation (`CLAUDE.md`, `README.md`) and the OpenSpec workflow.
There is no `pyproject.toml`, no virtual environment, and no quality tooling. UV is already installed on the
developer's machine (`~/.local/bin/uv`) and Python 3.14 is available. The `.gitignore` already excludes
`.venv/`, `.ruff_cache/`, `.pytest_cache/`, and `.mypy_cache/`.

The architecture (Clean Architecture + DDD + Ports & Adapters, modular monolith) imposes constraints that the
tooling should help enforce rather than fight: async at every I/O boundary, strict naming conventions, exact
decimal money, and a framework-independent pure `domain/`. This change deliberately sets up *only* the
development toolchain — no web framework, ORM, or auth mechanism, which the architecture notes keep deferred.

## Goals / Non-Goals

**Goals:**
- One reproducible way to install dependencies (UV + committed `uv.lock`).
- A pinned Python version (3.14+) provisioned automatically.
- Linting + formatting (Ruff) wired to rule families that reinforce project conventions.
- A test runner (pytest) for the pure domain.
- Strict static type checking (mypy).
- A single documented set of quality commands usable locally and in CI.

**Non-Goals:**
- Choosing a web framework (FastAPI vs BlackSheep) — deferred.
- Choosing an ORM / persistence layer — deferred.
- Auth strategy (JWT vs session) — deferred.
- CI pipeline configuration (a GitHub Actions workflow) — a likely follow-up change, not part of this one.
- Creating the `src/trocado/` package skeleton — that belongs to the first feature change, not to bootstrap.

## Decisions

**Decision 1 — UV as the single project manager.**
UV unifies dependency management, virtual environments, and Python version provisioning, and is from the same
authors as Ruff. *Alternatives:* Poetry (mature but slower, separate Python-version handling), pip + venv +
pip-tools (more moving parts, weaker reproducibility). *Why UV:* speed, one tool, native `requires-python`
provisioning, lockfile-first reproducibility.

**Decision 2 — `requires-python = ">=3.14"` + `.python-version`.**
3.14 is what the developer already runs, and a green-field project carries no legacy-version burden. *Trade-off:*
some third-party libraries or CI images may lag on 3.14; accepted because no runtime dependency is being added
yet, so the blast radius is minimal at bootstrap time. Revisit only if a needed library has no 3.14 wheel.

**Decision 3 — Ruff for lint *and* format, configured in `pyproject.toml`.**
`line-length = 120`; `select = ["E","F","I","UP","B","N","ASYNC","SIM"]`; exclude migration paths.
*Rationale per family:* `E`/`F` baseline correctness; `I` import order; `UP` modern syntax; `B` likely-bug
patterns; `N` naming (reinforces the project's strict naming table); `ASYNC` async-correctness (reinforces
"async everywhere"); `SIM` simplification. *Why not `ALL`:* too noisy on a green-field repo and pulls in
opinionated families (e.g. docstring rules) that would create churn before any code exists. The set can be
widened in a later change once code exists to measure the noise.

**Decision 4 — pytest as the test runner.**
The pure `domain/` is meant to be tested without spinning anything up; pytest is the de-facto standard with the
lowest ceremony. Added as a dev dependency so it never reaches a production install.

**Decision 5 — mypy (strict) now, `ty` later.**
The domain will carry rich types (value objects, exact-decimal money, entities); strict static checking pays off
immediately. `ty` (Astral) would keep the whole toolchain in one family and is fast, but it is pre-1.0 and not
yet trustworthy for strict enforcement. *Decision:* adopt mypy strict now; record `ty` as a future swap so the
intent is captured without betting correctness on an immature tool.

**Decision 6 — Standardize on `uv run <tool>`.**
All quality commands run through `uv run` so they resolve from the project `.venv` and need no global install.
This makes local and CI invocation identical and removes "works on my machine" tool-version drift.

## Risks / Trade-offs

- **Python 3.14 ecosystem lag** → No runtime deps are added at bootstrap, so impact is near-zero now; reassess
  when the first library with native deps is introduced.
- **mypy strict friction on early code** → Strict mode can be noisy, but starting strict on an empty codebase is
  far cheaper than retrofitting it later; per-module relaxations can be added narrowly if ever justified.
- **Ruff rule set may need tuning** → `B`/`SIM`/`N` can occasionally false-positive; handled with targeted
  `# noqa` or a scoped `ignore`, not by dropping a whole family.
- **`ty` divergence later** → Recording `ty` as a future swap risks it being forgotten; mitigated by capturing it
  explicitly in the spec and design so a future change can pick it up deliberately.

## Migration Plan

This is a green-field bootstrap; there is nothing to migrate and nothing to roll back beyond deleting the three
new files (`pyproject.toml`, `uv.lock`, `.python-version`) if abandoned. No production runtime is affected.

## Open Questions

- **CI wiring:** which CI provider/workflow runs these quality gates? Likely a separate follow-up change.
- **Updating `CLAUDE.md` "Stack and commands":** fold the canonical commands into the doc now or in the
  follow-up that also wires CI? Leaning toward the follow-up to keep this change strictly about the toolchain.
