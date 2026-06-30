from litestar.testing import TestClient

from trocado.core.infrastructure.http.app import build

_PERSON_A = {"name": "Ana Lima", "email": "ana@example.com", "password": "senha-segura-123"}
_PERSON_B = {"name": "Bruno Dias", "email": "bruno@example.com", "password": "senha-segura-456"}
_BUDGET_BODY = {"amount": "1500.00", "start_date": "2026-06-01", "end_date": "2026-06-30", "note": None}
_EXPENSE_BODY = {"amount": "49.90", "occurred_on": "2026-06-28"}


def _sign_up(client: TestClient, body: dict) -> str:  # type: ignore[type-arg]
    response = client.post("/v1/authentication/sign-up", json=body)
    assert response.status_code == 201
    return str(response.json()["token"])


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _form_pair(client: TestClient) -> tuple[str, str]:  # type: ignore[type-arg]
    token_a = _sign_up(client, _PERSON_A)
    token_b = _sign_up(client, _PERSON_B)
    invite = client.post("/v1/invites", headers=_auth(token_a)).json()
    client.post(f"/v1/invites/{invite['code']}/accept", headers=_auth(token_b))
    return token_a, token_b


# ---------------------------------------------------------------------------
# GET /v1/pair
# ---------------------------------------------------------------------------


def test_get_pair_returns_current_pair() -> None:
    with TestClient(app=build()) as client:
        token_a, token_b = _form_pair(client)
        response = client.get("/v1/pair", headers=_auth(token_a))

    assert response.status_code == 200
    body = response.json()
    assert "pair_id" in body
    assert body["partner_name"] == _PERSON_B["name"]


def test_get_pair_unpaired_returns_404() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        response = client.get("/v1/pair", headers=_auth(token_a))

    assert response.status_code == 404
    assert response.json()["code"] == "not-paired"


def test_get_pair_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.get("/v1/pair")

    assert response.status_code == 401


# ---------------------------------------------------------------------------
# DELETE /v1/pair
# ---------------------------------------------------------------------------


def test_delete_pair_dissolves_the_pair() -> None:
    with TestClient(app=build()) as client:
        token_a, _ = _form_pair(client)
        response = client.delete("/v1/pair", headers=_auth(token_a))

    assert response.status_code == 204


def test_delete_pair_then_get_returns_404() -> None:
    with TestClient(app=build()) as client:
        token_a, _ = _form_pair(client)
        client.delete("/v1/pair", headers=_auth(token_a))
        response = client.get("/v1/pair", headers=_auth(token_a))

    assert response.status_code == 404


def test_delete_pair_unpaired_returns_404() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        response = client.delete("/v1/pair", headers=_auth(token_a))

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# GET /v1/pair/budget
# ---------------------------------------------------------------------------


def test_get_couple_budget_returns_null_when_no_active_budget() -> None:
    with TestClient(app=build()) as client:
        token_a, _ = _form_pair(client)
        response = client.get("/v1/pair/budget", headers=_auth(token_a))

    assert response.status_code == 200
    assert response.json() is None


def test_get_couple_budget_unpaired_returns_404() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        response = client.get("/v1/pair/budget", headers=_auth(token_a))

    assert response.status_code == 404
    assert response.json()["code"] == "not-paired"


def test_get_couple_budget_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.get("/v1/pair/budget")

    assert response.status_code == 401


# ---------------------------------------------------------------------------
# GET /v1/pair/expenses
# ---------------------------------------------------------------------------


def test_get_couple_expenses_returns_empty_list_when_no_expenses() -> None:
    with TestClient(app=build()) as client:
        token_a, _ = _form_pair(client)
        response = client.get("/v1/pair/expenses", headers=_auth(token_a))

    assert response.status_code == 200
    assert response.json() == []


def test_get_couple_expenses_returns_expenses_with_perspective() -> None:
    with TestClient(app=build()) as client:
        token_a, token_b = _form_pair(client)
        client.post("/v1/expenses", json=_EXPENSE_BODY, headers=_auth(token_a))
        client.post("/v1/expenses", json={**_EXPENSE_BODY, "occurred_on": "2026-06-27"}, headers=_auth(token_b))
        response = client.get("/v1/pair/expenses", headers=_auth(token_a))

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 2
    perspectives = {e["perspective"] for e in body}
    assert perspectives == {"mine", "theirs"}


def test_get_couple_expenses_unpaired_returns_404() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        response = client.get("/v1/pair/expenses", headers=_auth(token_a))

    assert response.status_code == 404
    assert response.json()["code"] == "not-paired"


def test_get_couple_expenses_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.get("/v1/pair/expenses")

    assert response.status_code == 401
