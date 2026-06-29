from decimal import Decimal

from litestar.testing import TestClient

from trocado.core.infrastructure.http.app import build

_SIGN_UP_BODY = {"name": "Ana Silva", "email": "ana@example.com", "password": "senha-segura-123"}
_BUDGET_BODY = {
    "amount": "500.00",
    "note": "  mercado  ",
    "end_date": "2026-06-30",
    "start_date": "2026-06-01",
}


def _auth_header(client: TestClient) -> dict[str, str]:  # type: ignore[type-arg]
    response = client.post("/v1/authentication/sign-up", json=_SIGN_UP_BODY)
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['token']}"}


def test_post_budgets_creates_a_budget() -> None:
    """The real route, wired through the composition root, answers 201 with the created budget read-model."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.post("/v1/budgets", json=_BUDGET_BODY, headers=headers)

    assert response.status_code == 201
    body = response.json()

    assert len(body["id"]) == 36  # a canonical uuid7 string from the real identifier gateway
    assert body["note"] == "mercado"  # the domain trims the note
    assert body["end_date"] == "2026-06-30"
    assert body["start_date"] == "2026-06-01"
    assert Decimal(str(body["amount"])) == Decimal("500.00")


def test_a_malformed_body_returns_422_in_the_error_envelope() -> None:
    """A wrong-typed field is rejected at the boundary with 422 in the unified envelope, with field detail."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.post("/v1/budgets", json={**_BUDGET_BODY, "amount": True}, headers=headers)

    assert response.status_code == 422
    body = response.json()

    assert body["status"] == 422
    assert body["code"] == "validation"
    assert body["message"] == "Dados inválidos."
    amount_error = next(error for error in body["errors"] if error["key"] == "amount")
    assert amount_error["message"] == "Deve ser um número decimal."  # pt-BR, not Pydantic's English


def test_a_malformed_json_body_returns_400_in_pt_br() -> None:
    """Syntactically invalid JSON → 400 in the envelope, with a pt-BR message (not the parser's English)."""
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        response = client.post(
            "/v1/budgets",
            headers={**headers, "content-type": "application/json"},
            content=b'{"amount": ,"start_date":"2026-06-01","end_date":"2026-06-30"}',
        )

    assert response.status_code == 400
    body = response.json()
    assert "errors" not in body
    assert body["status"] == 400
    assert body["code"] == "bad-request"
    assert body["message"] == "Requisição inválida."


def test_an_overlapping_budget_returns_409_in_the_error_envelope() -> None:
    """A second overlapping create returns 409 in the unified envelope — and proves the shared singleton.

    The first budget persists in the app-scoped repository, so the second (same period) overlaps it. The 409
    framing comes from the merged error→status table; the envelope shape matches every other error.
    """
    with TestClient(app=build()) as client:
        headers = _auth_header(client)
        first = client.post("/v1/budgets", json=_BUDGET_BODY, headers=headers)
        second = client.post("/v1/budgets", json=_BUDGET_BODY, headers=headers)

    assert first.status_code == 201
    assert second.status_code == 409
    body = second.json()
    assert "errors" not in body  # omitted when there are no field-level errors
    assert body["status"] == 409
    assert body["code"] == "overlapping-budget"
    assert body["message"] == "Já existe um orçamento neste período."
