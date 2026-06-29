"""Load tests for the Trocado HTTP edge.

Baseline numbers are PRE-ORM (in-memory repositories). They will be significantly
different once a real database lands — re-run and establish a new baseline then.

Usage:
  uv run poe serve          # terminal 1 — start the app
  uv run poe stress         # terminal 2 — headless run (50 users, 60s)
  uv run locust             # terminal 2 — interactive UI at http://localhost:8089
"""

from __future__ import annotations

import uuid

from locust import HttpUser, between, task


class TestBudgetingFlow(HttpUser):
    wait_time = between(0.5, 2)

    _token: str
    _month_offset: int  # shifts the budget window each task call to avoid the non-overlap 409

    def on_start(self) -> None:
        email = f"user-{uuid.uuid4().hex[:8]}@stress.test"
        resp = self.client.post(
            "/v1/authentication/sign-up",
            json={"name": "Stress User", "email": email, "password": "senha-segura-123"},
        )
        self._token = resp.json()["token"]
        self._month_offset = 1

    @task
    def create_budget(self) -> None:
        # Each call uses a different month so the non-overlap invariant is never triggered.
        # Month arithmetic stays in [01..12]; for a 60s run with wait_time ~1s per user this
        # stays well within bounds before the user is recycled.
        month = self._month_offset % 12 + 1
        year = 2026 + self._month_offset // 12
        start = f"{year}-{month:02d}-01"
        end = f"{year}-{month:02d}-28"
        self._month_offset += 1

        self.client.post(
            "/v1/budgets",
            json={"amount": "500.00", "start_date": start, "end_date": end},
            headers={"Authorization": f"Bearer {self._token}"},
        )
