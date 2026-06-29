---
name: "Trocado: Stress"
description: Scaffold a Locust load-test scenario for a new HTTP flow, or run the existing suite. Invokes the load-test skill to add tests/stress/test_<flow>.py and documents running poe stress against the real server.
category: Quality
tags: [trocado, load-test, locust, stress, performance]
---

Scaffold or run load tests for a Trocado HTTP flow.

**Input**: optionally name the flow or route to test (e.g. `/trocado:stress budgeting`). If omitted, just run
the existing suite.

**Steps**

### If a flow name is given — scaffold a new scenario

1. Invoke the `load-test` skill with the given flow name. It will:
   - Create `tests/stress/test_<flow>.py` following the `Test<Flow>(HttpUser)` template.
   - Wire `on_start` with sign-up + token storage.
   - Add one or more `@task` methods for the named routes.
   - Verify `uv run locust --list -f tests/stress/` lists the new class.

2. Remind the user to:
   - Start the server in a separate terminal: `uv run poe serve`
   - Then run the suite: `uv run poe stress`

### If no flow name is given — run the existing suite

```bash
uv run poe stress
```

> **Prerequisite:** `uv run poe serve` must be running in another terminal before this command is used.
> `poe stress` will fail with *connection refused* if the app is not up.

### Interpreting results

- **Failure rate 0%** — the route handles the load without errors.
- **Failure rate > 0%** — investigate: likely an unhandled 4xx/5xx under concurrency (e.g. a lock contention
  in the in-memory repository, a non-overlap 409 from colliding budget dates across users). Fix the scenario
  inputs before concluding it's a performance issue.
- **Numbers are pre-ORM.** In-memory repositories will report much higher RPS than a real database. Record the
  baseline in the file's docstring and re-establish it when persistence lands.

> Load tests are **opt-in** — they never run under `poe check` and do not gate CI. Run them manually when a
> new HTTP edge lands, or when you want to verify a change has not regressed throughput.

See `CLAUDE.md` → "Load/stress tests", "Stack and commands", and the `load-test` skill.
