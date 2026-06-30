from decimal import Decimal

from litestar.testing import TestClient

from trocado.core.infrastructure.http.app import build

_SIGN_UP_BODY = {"name": "Ana Silva", "email": "ana@example.com", "password": "senha-segura-123"}
_EXPENSE_BODY = {"amount": "49.90", "occurred_on": "2026-06-28", "description": "  almoço  "}


def _auth_header(client: TestClient) -> dict[str, str]:  # type: ignore[type-arg]
    response = client.post("/v1/authentication/sign-up", json=_SIGN_UP_BODY)
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['token']}"}


# ---------------------------------------------------------------------------
# POST /v1/expenses
# ---------------------------------------------------------------------------


def test_post_expenses_creates_an_expense() -> None:
    """The real route, wired through the composition root, answers 201 with the created expense read-model."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.post("/v1/expenses", json=_EXPENSE_BODY, headers=headers)

    assert response.status_code == 201
    body = response.json()

    assert len(body["id"]) == 36
    assert body["description"] == "almoço"  # domain trims surrounding whitespace
    assert body["occurred_on"] == "2026-06-28"
    assert Decimal(str(body["amount"])) == Decimal("49.90")


def test_post_expenses_missing_required_field_returns_422() -> None:
    """A body without 'amount' is rejected at the boundary — the use case is never invoked."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.post("/v1/expenses", json={"occurred_on": "2026-06-28"}, headers=headers)

    assert response.status_code == 422
    body = response.json()
    assert body["status"] == 422
    assert body["code"] == "validation"
    assert body["message"] == "Dados inválidos."
    assert any(e["key"] == "amount" for e in body["errors"])


def test_post_expenses_wrong_typed_field_returns_422() -> None:
    """A boolean amount is a type error — rejected with pt-BR per-field message."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.post("/v1/expenses", json={**_EXPENSE_BODY, "amount": True}, headers=headers)

    assert response.status_code == 422
    body = response.json()
    amount_error = next(e for e in body["errors"] if e["key"] == "amount")
    assert amount_error["message"] == "Deve ser um número decimal."


def test_post_expenses_non_positive_amount_returns_422() -> None:
    """A zero amount violates the domain invariant — the use case raises InvalidAmountError → 422."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.post("/v1/expenses", json={**_EXPENSE_BODY, "amount": "0"}, headers=headers)

    assert response.status_code == 422
    body = response.json()
    assert "errors" not in body
    assert body["status"] == 422


def test_post_expenses_without_auth_returns_401() -> None:
    """Authenticated route: missing token → 401 before the handler body runs."""
    with TestClient(app=build()) as client:
        response = client.post("/v1/expenses", json=_EXPENSE_BODY)

    assert response.status_code == 401
    body = response.json()
    assert body["status"] == 401
    assert body["code"] == "invalid-session"


# ---------------------------------------------------------------------------
# GET /v1/expenses
# ---------------------------------------------------------------------------


def test_get_expenses_returns_live_expenses() -> None:
    """After recording two expenses, GET /v1/expenses returns both, most-recent-first."""
    body_1 = {"amount": "20.00", "occurred_on": "2026-06-27"}
    body_2 = {"amount": "30.00", "occurred_on": "2026-06-28"}

    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        client.post("/v1/expenses", json=body_1, headers=headers)
        client.post("/v1/expenses", json=body_2, headers=headers)
        response = client.get("/v1/expenses", headers=headers)

    assert response.status_code == 200
    items = response.json()
    assert len(items) == 2
    assert items[0]["occurred_on"] == "2026-06-28"  # most-recent first
    assert items[1]["occurred_on"] == "2026-06-27"


def test_get_expenses_empty_list() -> None:
    """A person with no expenses receives an empty array and 200 OK."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.get("/v1/expenses", headers=headers)

    assert response.json() == []
    assert response.status_code == 200


def test_get_expenses_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.get("/v1/expenses")

    assert response.status_code == 401


# ---------------------------------------------------------------------------
# PATCH /v1/expenses/{expense_id}
# ---------------------------------------------------------------------------


def test_patch_expense_updates_the_expense() -> None:
    """PATCH /v1/expenses/{id} overwrites all editable fields, answers 200 with updated read-model."""
    update_body = {"amount": "55.00", "occurred_on": "2026-06-29", "description": "jantar"}

    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        created = client.post("/v1/expenses", json=_EXPENSE_BODY, headers=headers)
        expense_id = created.json()["id"]
        response = client.patch(f"/v1/expenses/{expense_id}", json=update_body, headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == expense_id
    assert body["description"] == "jantar"
    assert body["occurred_on"] == "2026-06-29"
    assert Decimal(str(body["amount"])) == Decimal("55.00")


def test_patch_expense_unknown_id_returns_404() -> None:
    """An unknown expense_id is rejected with 404 — non-leaking, same as foreign owner."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.patch(
            "/v1/expenses/nonexistent-id",
            json={"amount": "10.00", "occurred_on": "2026-06-28"},
            headers=headers,
        )

    assert response.status_code == 404
    body = response.json()
    assert body["status"] == 404
    assert body["code"] == "expense-not-found"


def test_patch_expense_non_positive_amount_returns_422() -> None:
    """Updating with a zero amount violates the domain invariant — 422 with unified envelope."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        created = client.post("/v1/expenses", json=_EXPENSE_BODY, headers=headers)
        expense_id = created.json()["id"]
        response = client.patch(
            f"/v1/expenses/{expense_id}",
            json={"amount": "-1.00", "occurred_on": "2026-06-28"},
            headers=headers,
        )

    assert response.status_code == 422
    body = response.json()
    assert "errors" not in body
    assert body["status"] == 422


def test_patch_expense_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.patch("/v1/expenses/some-id", json={"amount": "10.00", "occurred_on": "2026-06-28"})

    assert response.status_code == 401


# ---------------------------------------------------------------------------
# DELETE /v1/expenses/{expense_id}
# ---------------------------------------------------------------------------


def test_delete_expense_soft_deletes_and_returns_204() -> None:
    """DELETE /v1/expenses/{id} soft-deletes the expense and answers 204 with no body."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        created = client.post("/v1/expenses", json=_EXPENSE_BODY, headers=headers)
        expense_id = created.json()["id"]
        delete_response = client.delete(f"/v1/expenses/{expense_id}", headers=headers)
        list_response = client.get("/v1/expenses", headers=headers)

    assert list_response.json() == []  # expense no longer appears in normal reads
    assert delete_response.content == b""
    assert delete_response.status_code == 204


def test_delete_expense_unknown_id_returns_404() -> None:
    """An unknown expense_id is rejected with 404."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.delete("/v1/expenses/nonexistent-id", headers=headers)

    assert response.status_code == 404
    body = response.json()
    assert body["code"] == "expense-not-found"


def test_delete_expense_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.delete("/v1/expenses/some-id")

    assert response.status_code == 401
