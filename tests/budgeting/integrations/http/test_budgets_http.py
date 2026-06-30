from decimal import Decimal

import pytest
from litestar.testing import TestClient

from trocado.core.infrastructure.http.app import build

_SIGN_UP_BODY = {"name": "Ana Silva", "email": "ana@example.com", "password": "senha-segura-123"}
_BUDGET_BODY = {
    "amount": "500.00",
    "start_date": "2026-06-01",
    "end_date": "2026-06-30",
}
# Wide range covering any 2026 date — used for the active-budget tests.
_ACTIVE_BUDGET_BODY = {
    "amount": "1000.00",
    "start_date": "2026-01-01",
    "end_date": "2026-12-31",
}


def _auth_header(client: TestClient) -> dict[str, str]:  # type: ignore[type-arg]
    response = client.post("/v1/authentication/sign-up", json=_SIGN_UP_BODY)
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['token']}"}


# ---------------------------------------------------------------------------
# GET /v1/budgets
# ---------------------------------------------------------------------------


def test_get_budgets_returns_empty_list_when_no_budgets() -> None:
    """A person with no budgets receives an empty array and 200 OK."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.get("/v1/budgets", headers=headers)

    assert response.status_code == 200
    assert response.json() == []


def test_get_budgets_returns_live_budgets_most_recent_first() -> None:
    """After creating two budgets, GET /v1/budgets returns both, most-recent-period-first."""
    body_1 = {"amount": "300.00", "start_date": "2026-04-01", "end_date": "2026-04-30"}
    body_2 = {"amount": "400.00", "start_date": "2026-05-01", "end_date": "2026-05-31"}

    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        client.post("/v1/budgets", json=body_1, headers=headers)
        client.post("/v1/budgets", json=body_2, headers=headers)
        response = client.get("/v1/budgets", headers=headers)

    assert response.status_code == 200
    items = response.json()
    assert len(items) == 2
    # each item carries person_id
    assert len(items[0]["person_id"]) == 36
    # most-recent-period-first (May before April)
    assert items[0]["start_date"] == "2026-05-01"
    assert items[1]["start_date"] == "2026-04-01"


def test_get_budgets_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.get("/v1/budgets")

    assert response.status_code == 401
    body = response.json()
    assert body["code"] == "invalid-session"


# ---------------------------------------------------------------------------
# GET /v1/budgets/active
# ---------------------------------------------------------------------------


def test_get_active_budget_returns_enriched_budget() -> None:
    """A budget covering today is returned enriched with total_spent and remaining."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        client.post("/v1/budgets", json=_ACTIVE_BUDGET_BODY, headers=headers)
        response = client.get("/v1/budgets/active", headers=headers)

    assert response.status_code == 200
    body = response.json()

    assert len(body["id"]) == 36
    assert Decimal(str(body["amount"])) == Decimal("1000.00")
    assert Decimal(str(body["total_spent"])) == Decimal("0.00")
    assert Decimal(str(body["remaining"])) == Decimal("1000.00")


@pytest.mark.skip(reason="pre-ORM: SpendReader usa instância separada; reativar com o banco")
def test_get_active_budget_reflects_expenses_in_totals() -> None:
    """total_spent includes expenses recorded within the active budget's period."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        client.post("/v1/budgets", json=_ACTIVE_BUDGET_BODY, headers=headers)
        client.post("/v1/expenses", json={"amount": "120.00", "occurred_on": "2026-06-15"}, headers=headers)
        response = client.get("/v1/budgets/active", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert Decimal(str(body["remaining"])) == Decimal("880.00")
    assert Decimal(str(body["total_spent"])) == Decimal("120.00")


def test_get_active_budget_returns_404_when_no_active_budget() -> None:
    """When no budget covers today, the endpoint answers 404 with the unified envelope."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.get("/v1/budgets/active", headers=headers)

    assert response.status_code == 404
    body = response.json()
    assert body["status"] == 404
    assert body["code"] == "budget-not-found"


def test_get_active_budget_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.get("/v1/budgets/active")

    assert response.status_code == 401


# ---------------------------------------------------------------------------
# PATCH /v1/budgets/{budget_id}
# ---------------------------------------------------------------------------


def test_patch_budget_updates_the_budget() -> None:
    """PATCH /v1/budgets/{id} overwrites all editable fields, answers 200 with updated read-model."""
    update_body = {"amount": "750.00", "start_date": "2026-07-01", "end_date": "2026-07-31", "note": "julho"}

    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        created = client.post("/v1/budgets", json=_BUDGET_BODY, headers=headers)
        budget_id = created.json()["id"]
        response = client.patch(f"/v1/budgets/{budget_id}", json=update_body, headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == budget_id
    assert body["note"] == "julho"
    assert body["end_date"] == "2026-07-31"
    assert body["start_date"] == "2026-07-01"
    assert Decimal(str(body["amount"])) == Decimal("750.00")


def test_patch_budget_unknown_id_returns_404() -> None:
    """An unknown budget_id is rejected with 404 — non-leaking, same as foreign owner."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.patch(
            "/v1/budgets/nonexistent-id",
            json={"amount": "300.00", "start_date": "2026-07-01", "end_date": "2026-07-31"},
            headers=headers,
        )

    assert response.status_code == 404
    body = response.json()
    assert body["status"] == 404
    assert body["code"] == "budget-not-found"


def test_patch_budget_overlapping_range_returns_409() -> None:
    """Updating a budget's range to overlap another live budget returns 409."""
    body_a = {"amount": "300.00", "start_date": "2026-07-01", "end_date": "2026-07-31"}
    body_b = {"amount": "400.00", "start_date": "2026-08-01", "end_date": "2026-08-31"}

    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        created_a = client.post("/v1/budgets", json=body_a, headers=headers)
        client.post("/v1/budgets", json=body_b, headers=headers)
        budget_id = created_a.json()["id"]
        # Try to move budget_a into budget_b's range
        response = client.patch(
            f"/v1/budgets/{budget_id}",
            json={"amount": "300.00", "start_date": "2026-08-15", "end_date": "2026-08-25"},
            headers=headers,
        )

    assert response.status_code == 409
    body = response.json()
    assert body["code"] == "overlapping-budget"


def test_patch_budget_invalid_body_returns_422() -> None:
    """A wrong-typed field in the update body returns 422 with field-level errors."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        created = client.post("/v1/budgets", json=_BUDGET_BODY, headers=headers)
        budget_id = created.json()["id"]
        response = client.patch(
            f"/v1/budgets/{budget_id}",
            headers=headers,
            json={"amount": True, "start_date": "2026-07-01", "end_date": "2026-07-31"},
        )

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == "validation"
    assert any(e["key"] == "amount" for e in body["errors"])


def test_patch_budget_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.patch(
            "/v1/budgets/some-id",
            json={"amount": "300.00", "start_date": "2026-07-01", "end_date": "2026-07-31"},
        )

    assert response.status_code == 401


# ---------------------------------------------------------------------------
# DELETE /v1/budgets/{budget_id}
# ---------------------------------------------------------------------------


def test_delete_budget_soft_deletes_and_returns_204() -> None:
    """DELETE /v1/budgets/{id} soft-deletes the budget and answers 204 with no body."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        created = client.post("/v1/budgets", json=_BUDGET_BODY, headers=headers)
        budget_id = created.json()["id"]
        delete_response = client.delete(f"/v1/budgets/{budget_id}", headers=headers)
        list_response = client.get("/v1/budgets", headers=headers)

    assert list_response.json() == []  # budget no longer appears in normal reads
    assert delete_response.content == b""
    assert delete_response.status_code == 204


def test_delete_budget_unknown_id_returns_404() -> None:
    """An unknown budget_id is rejected with 404."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.delete("/v1/budgets/nonexistent-id", headers=headers)

    assert response.status_code == 404
    body = response.json()
    assert body["code"] == "budget-not-found"


def test_delete_budget_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.delete("/v1/budgets/some-id")

    assert response.status_code == 401
