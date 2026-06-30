"""Load tests for the pairing HTTP edge.

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


class TestPairingFlow(HttpUser):
    """Simulates the full pairing lifecycle: create invite → accept → view pair → dissolve."""

    wait_time = between(0.5, 2)

    _token_a: str
    _token_b: str
    _pair_id: str | None
    _invite_code: str | None

    def on_start(self) -> None:
        uid = uuid.uuid4().hex[:8]
        resp_a = self.client.post(
            "/v1/authentication/sign-up",
            json={"name": f"User A {uid}", "email": f"a-{uid}@stress.test", "password": "senha-segura-123"},
        )
        self._token_a = resp_a.json()["token"]

        resp_b = self.client.post(
            "/v1/authentication/sign-up",
            json={"name": f"User B {uid}", "email": f"b-{uid}@stress.test", "password": "senha-segura-456"},
        )
        self._token_b = resp_b.json()["token"]
        self._pair_id = None
        self._invite_code = None

    @task(2)
    def create_invite(self) -> None:
        if self._pair_id is not None:
            return
        resp = self.client.post(
            "/v1/invites",
            headers={"Authorization": f"Bearer {self._token_a}"},
        )
        if resp.status_code == 201:
            self._invite_code = resp.json()["code"]

    @task(2)
    def accept_invite(self) -> None:
        if self._invite_code is None or self._pair_id is not None:
            return
        resp = self.client.post(
            f"/v1/invites/{self._invite_code}/accept",
            headers={"Authorization": f"Bearer {self._token_b}"},
        )
        if resp.status_code == 201:
            self._pair_id = resp.json()["pair_id"]
            self._invite_code = None

    @task(3)
    def get_current_pair(self) -> None:
        if self._pair_id is None:
            return
        self.client.get(
            "/v1/pair",
            headers={"Authorization": f"Bearer {self._token_a}"},
        )

    @task(2)
    def get_couple_expenses(self) -> None:
        if self._pair_id is None:
            return
        self.client.get(
            "/v1/pair/expenses",
            headers={"Authorization": f"Bearer {self._token_a}"},
        )

    @task(1)
    def get_couple_budget(self) -> None:
        if self._pair_id is None:
            return
        self.client.get(
            "/v1/pair/budget",
            headers={"Authorization": f"Bearer {self._token_a}"},
        )

    @task(1)
    def dissolve_pair(self) -> None:
        if self._pair_id is None:
            return
        resp = self.client.delete(
            "/v1/pair",
            headers={"Authorization": f"Bearer {self._token_a}"},
        )
        if resp.status_code == 204:
            self._pair_id = None
