"""Load tests for the expenses HTTP edge.

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


class TestExpensesFlow(HttpUser):
    wait_time = between(0.5, 2)

    _token: str
    _expense_id: str | None

    def on_start(self) -> None:
        email = f"user-{uuid.uuid4().hex[:8]}@stress.test"
        resp = self.client.post(
            "/v1/authentication/sign-up",
            json={"name": "Stress User", "email": email, "password": "senha-segura-123"},
        )
        self._token = resp.json()["token"]
        self._expense_id = None

    @task(3)
    def record_expense(self) -> None:
        resp = self.client.post(
            "/v1/expenses",
            json={"amount": "25.50", "occurred_on": "2026-06-28", "description": "café"},
            headers={"Authorization": f"Bearer {self._token}"},
        )
        if resp.status_code == 201:
            self._expense_id = resp.json()["id"]

    @task(2)
    def list_expenses(self) -> None:
        self.client.get(
            "/v1/expenses",
            headers={"Authorization": f"Bearer {self._token}"},
        )

    @task(1)
    def update_expense(self) -> None:
        if self._expense_id is None:
            return
        self.client.patch(
            f"/v1/expenses/{self._expense_id}",
            json={"amount": "30.00", "occurred_on": "2026-06-28", "description": "almoço"},
            headers={"Authorization": f"Bearer {self._token}"},
        )

    @task(1)
    def delete_expense(self) -> None:
        if self._expense_id is None:
            return
        resp = self.client.delete(
            f"/v1/expenses/{self._expense_id}",
            headers={"Authorization": f"Bearer {self._token}"},
        )
        if resp.status_code == 204:
            self._expense_id = None
