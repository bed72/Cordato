---
name: load-test
description: Scaffold a Locust HttpUser scenario in tests/stress/test_<flow>.py for a Trocado/Cordato HTTP flow. Each scenario signs up (or signs in) to obtain a Bearer token on_start, then exercises one or more routes via @task. Scenarios run against the real server (poe serve must be up); poe stress runs them headless. Use when a new HTTP flow has been exposed and you want a load baseline before the ORM lands.
metadata:
  author: trocado
  version: "1.0"
---

# Load Test (Locust)

Scaffold a **Locust `HttpUser` scenario** in `tests/stress/` for a named HTTP flow. This is **not a pytest
test** — Locust scenarios are never discovered by `poe check` and do not live under a feature's
`integrations/`. They are project-level, run against the real running server, and establish a performance
baseline (pre-ORM).

## Where it lives

```
tests/stress/
  __init__.py
  test_<flow>.py     # e.g. test_budgeting_flow.py, test_authentication_flow.py
```

One file per logical flow (authentication, budgeting, expenses, …). **No subdirectory per feature** — all
Locust files share the same flat `tests/stress/` package.

## Scenario shape

```python
"""Load test for <flow>.

Baseline numbers are PRE-ORM (in-memory repositories). They will be significantly
different once a real database lands — re-run and establish a new baseline then.

Usage:
  uv run poe serve      # terminal 1 — start the app
  uv run poe stress     # terminal 2 — headless run (50 users, 60s)
  uv run locust         # terminal 2 — interactive UI at http://localhost:8089
"""

from __future__ import annotations

import uuid

from locust import HttpUser, between, task


class Test<Flow>(HttpUser):
    wait_time = between(0.5, 2)

    _token: str

    def on_start(self) -> None:
        # Each virtual user signs up with a unique email to avoid conflicts.
        email = f"user-{uuid.uuid4().hex[:8]}@stress.test"
        resp = self.client.post(
            "/v1/authentication/sign-up",
            json={"name": "Stress User", "email": email, "password": "senha-segura-123"},
        )
        self._token = resp.json()["token"]

    @task
    def <operation>(self) -> None:
        self.client.post(
            "/v1/<resource>",
            json={...},
            headers={"Authorization": f"Bearer {self._token}"},
        )
```

## Rules

1. **Class named `Test<Flow>(HttpUser)`** — the `Test` prefix is a Locust convention, NOT pytest. The file is
   named `test_<flow>.py` for consistency but pytest never discovers it (it contains no `def test_*` functions).
2. **`on_start` always authenticates.** Each virtual user creates a unique account (random email suffix) and
   stores the token. This prevents test state leaking between users and avoids the non-overlap 409 from budget
   creation.
3. **`@task` methods exercise one route each.** If the invariant requires unique inputs across calls (e.g. non-
   overlapping budget dates), use an `_offset` counter incremented each task to shift the window.
4. **`wait_time = between(0.5, 2)`** — keeps the load realistic and prevents flooding in-memory storage.
5. **No assertions in task methods** — Locust tracks failures from HTTP status codes automatically.
6. **The file header MUST note "PRE-ORM baseline"** — these numbers are meaningless once persistence lands.
7. **No spec-first gate** — stress tests are tooling, not feature behavior. No OpenSpec change required.
8. **`poe check` never includes `tests/stress/`** — confirmed by `pytest` discovering only `testpaths = ["tests"]`
   without Locust classes matching its test-function criteria.

## Flow

1. Identify the HTTP flow(s) to load-test (usually a freshly exposed endpoint or a full roundtrip).
2. Create `tests/stress/test_<flow>.py` using the template above. Add `__init__.py` if missing.
3. Wire the `@task` methods to the relevant routes with realistic payloads.
4. Verify Locust sees the scenario: `uv run locust --list -f tests/stress/` must list `Test<Flow>`.
5. Run: `uv run poe serve` (terminal 1) then `uv run poe stress` (terminal 2). Confirm 0% failure rate.
6. Note the RPS/latency numbers in a comment at the top of the file as the pre-ORM baseline.

## Running the suite

```bash
# Start the server first
uv run poe serve

# Then in another terminal — headless Locust (50 users, 5/s ramp-up, 60 s)
uv run poe stress

# Or interactive UI at http://localhost:8089
uv run locust
```

`poe stress` is defined in `pyproject.toml`:
```toml
stress = "locust -f tests/stress/ --host http://127.0.0.1:8000 --headless -u 50 -r 5 -t 60s"
```

Override any parameter via CLI: `uv run poe stress -- -u 100 -t 120s`.

See `CLAUDE.md` → "Load/stress tests" and "Stack and commands".
