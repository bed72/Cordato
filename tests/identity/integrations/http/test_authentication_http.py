from litestar.testing import TestClient

from trocado.core.infrastructure.http.app import build

_SIGN_UP_BODY = {"name": "Ana Silva", "email": "ana@example.com", "password": "senha-segura-123"}
_SIGN_IN_BODY = {"email": "ana@example.com", "password": "senha-segura-123"}


def _sign_up(client: TestClient) -> dict[str, object]:  # type: ignore[type-arg]
    response = client.post("/v1/authentication/sign-up", json=_SIGN_UP_BODY)
    assert response.status_code == 201
    return response.json()  # type: ignore[no-any-return]


# ── sign-up ──────────────────────────────────────────────────────────────────


def test_sign_up_creates_account_and_returns_session() -> None:
    with TestClient(app=build()) as client:
        response = client.post("/v1/authentication/sign-up", json=_SIGN_UP_BODY)

    assert response.status_code == 201
    body = response.json()
    assert "expires_at" in body
    assert body["person"]["name"] == "Ana Silva"
    assert body["person"]["email"] == "ana@example.com"
    assert isinstance(body["token"], str) and len(body["token"]) > 10
    assert "password" not in body and "password" not in body["person"]


def test_sign_up_duplicate_email_returns_409() -> None:
    with TestClient(app=build()) as client:
        client.post("/v1/authentication/sign-up", json=_SIGN_UP_BODY)
        response = client.post("/v1/authentication/sign-up", json=_SIGN_UP_BODY)

    assert response.status_code == 409
    body = response.json()
    assert "errors" not in body
    assert body["status"] == 409
    assert body["code"] == "email-already-in-use"


def test_sign_up_invalid_email_returns_422() -> None:
    with TestClient(app=build()) as client:
        response = client.post("/v1/authentication/sign-up", json={**_SIGN_UP_BODY, "email": "not-an-email"})

    assert response.status_code == 422
    body = response.json()
    assert body["status"] == 422
    assert body["code"] == "invalid-email"


def test_sign_up_missing_field_returns_422_with_field_detail() -> None:
    with TestClient(app=build()) as client:
        response = client.post("/v1/authentication/sign-up", json={"email": "ana@example.com"})

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == "validation"
    assert any(e["key"] in ("password", "name") for e in body["errors"])


# ── sign-in ──────────────────────────────────────────────────────────────────


def test_sign_in_with_valid_credential_returns_200_with_session() -> None:
    with TestClient(app=build()) as client:
        _sign_up(client)
        response = client.post("/v1/authentication/sign-in", json=_SIGN_IN_BODY)

    assert response.status_code == 200
    body = response.json()
    assert body["person"]["email"] == "ana@example.com"
    assert isinstance(body["token"], str) and len(body["token"]) > 10


def test_sign_in_with_wrong_password_returns_401() -> None:
    with TestClient(app=build()) as client:
        _sign_up(client)
        response = client.post("/v1/authentication/sign-in", json={**_SIGN_IN_BODY, "password": "wrong"})

    assert response.status_code == 401
    body = response.json()
    assert "errors" not in body
    assert body["status"] == 401
    assert body["code"] == "invalid-credentials"


def test_sign_in_with_unknown_email_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.post("/v1/authentication/sign-in", json={"email": "ghost@example.com", "password": "x" * 8})

    assert response.status_code == 401
    body = response.json()
    assert body["code"] == "invalid-credentials"


# ── sign-out ─────────────────────────────────────────────────────────────────


def test_sign_out_with_valid_token_returns_204() -> None:
    with TestClient(app=build()) as client:
        session = _sign_up(client)
        response = client.post(
            "/v1/authentication/sign-out",
            headers={"Authorization": f"Bearer {session['token']}"},
        )

    assert response.status_code == 204


def test_sign_out_with_unknown_token_returns_204_no_op() -> None:
    with TestClient(app=build()) as client:
        response = client.post(
            "/v1/authentication/sign-out",
            headers={"Authorization": "Bearer totally-unknown-token"},
        )

    assert response.status_code == 204


def test_sign_out_without_header_returns_204_no_op() -> None:
    with TestClient(app=build()) as client:
        response = client.post("/v1/authentication/sign-out")

    assert response.status_code == 204


# ── protected routes ──────────────────────────────────────────────────────────


def test_protected_route_without_token_returns_401() -> None:
    budget_body = {"amount": "500.00", "start_date": "2026-06-01", "end_date": "2026-06-30"}
    with TestClient(app=build()) as client:
        response = client.post("/v1/budgets", json=budget_body)

    assert response.status_code == 401
    body = response.json()
    assert body["code"] == "invalid-session"


def test_protected_route_with_valid_token_succeeds() -> None:
    budget_body = {"amount": "500.00", "start_date": "2026-06-01", "end_date": "2026-06-30"}
    with TestClient(app=build()) as client:
        session = _sign_up(client)
        response = client.post(
            "/v1/budgets",
            json=budget_body,
            headers={"Authorization": f"Bearer {session['token']}"},
        )

    assert response.status_code == 201
