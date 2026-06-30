"""Load tests for the complete budgeting HTTP edge.

Exercises list, active, update, and delete alongside create. The active-budget endpoint requires
a budget that covers today, so the scenario creates one wide-range budget per user (the full year)
before starting tasks. Subsequent creates use per-task month windows to avoid the non-overlap 409.

Baseline numbers are PRE-ORM (in-memory repositories). Re-run after the ORM lands to
establish a new baseline.

Usage:
  uv run poe serve          # terminal 1 — start the app
  uv run poe stress         # terminal 2 — headless run (50 users, 60s)
  uv run locust             # terminal 2 — interactive UI at http://localhost:8089
"""

from __future__ import annotations

import uuid

from locust import HttpUser, between, task


class TestBudgetsFlow(HttpUser):
    wait_time = between(0.5, 2)

    _token: str
    _budget_id: str | None
    _month_offset: int

    def on_start(self) -> None:
        email = f"user-{uuid.uuid4().hex[:8]}@stress.test"
        resp = self.client.post(
            "/v1/authentication/sign-up",
            json={"name": "Stress User", "email": email, "password": "senha-segura-123"},
        )
        self._token = resp.json()["token"]
        self._budget_id = None
        self._month_offset = 2  # offset 0 is reserved for the wide-range active budget

        # Create a budget covering the full year so /active always finds one.
        self.client.post(
            "/v1/budgets",
            json={"amount": "5000.00", "start_date": "2026-01-01", "end_date": "2026-12-31"},
            headers={"Authorization": f"Bearer {self._token}"},
        )

    @task(3)
    def create_budget(self) -> None:
        # Each call uses a different future-year month so it never overlaps the wide-range budget or itself.
        year = 2027 + self._month_offset // 12
        month = self._month_offset % 12 + 1
        start = f"{year}-{month:02d}-01"
        end = f"{year}-{month:02d}-28"
        self._month_offset += 1

        resp = self.client.post(
            "/v1/budgets",
            json={"amount": "500.00", "start_date": start, "end_date": end},
            headers={"Authorization": f"Bearer {self._token}"},
        )
        if resp.status_code == 201:
            self._budget_id = resp.json()["id"]

    @task(2)
    def list_budgets(self) -> None:
        self.client.get(
            "/v1/budgets",
            headers={"Authorization": f"Bearer {self._token}"},
        )

    @task(2)
    def active_budget(self) -> None:
        self.client.get(
            "/v1/budgets/active",
            headers={"Authorization": f"Bearer {self._token}"},
        )

    @task(1)
    def update_budget(self) -> None:
        if self._budget_id is None:
            return
        year = 2030 + self._month_offset // 12
        month = self._month_offset % 12 + 1
        self._month_offset += 1
        start = f"{year}-{month:02d}-01"
        end = f"{year}-{month:02d}-28"
        resp = self.client.patch(
            f"/v1/budgets/{self._budget_id}",
            json={"amount": "600.00", "start_date": start, "end_date": end},
            headers={"Authorization": f"Bearer {self._token}"},
        )
        if resp.status_code == 200:
            self._budget_id = resp.json()["id"]

    @task(1)
    def delete_budget(self) -> None:
        if self._budget_id is None:
            return
        resp = self.client.delete(
            f"/v1/budgets/{self._budget_id}",
            headers={"Authorization": f"Bearer {self._token}"},
        )
        if resp.status_code == 204:
            self._budget_id = None
