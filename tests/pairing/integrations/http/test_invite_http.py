import pytest
from litestar.testing import TestClient

from trocado.core.infrastructure.http.app import build

_PRE_ORM = pytest.mark.skip(
    reason=(
        "pre-ORM: pairing usa PersonRepository isolado; "
        "accept-invite requer PersonDirectory compartilhado com identity. "
        "Resolvido quando o ORM chegar."
    )
)

_PERSON_A = {"name": "Ana Lima", "email": "ana@example.com", "password": "senha-segura-123"}
_PERSON_B = {"name": "Bruno Dias", "email": "bruno@example.com", "password": "senha-segura-456"}


def _sign_up(client: TestClient, body: dict) -> str:  # type: ignore[type-arg]
    response = client.post("/v1/authentication/sign-up", json=body)
    assert response.status_code == 201
    return str(response.json()["token"])


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# POST /v1/invites — create invite
# ---------------------------------------------------------------------------


def test_post_invites_creates_invite_code() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        response = client.post("/v1/invites", headers=_auth(token_a))

    assert response.status_code == 201
    body = response.json()
    assert len(body["code"]) > 0
    assert body["consumed_at"] is None
    assert "expires_at" in body


def test_post_invites_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        response = client.post("/v1/invites")

    assert response.status_code == 401


# ---------------------------------------------------------------------------
# DELETE /v1/invites/{code} — revoke
# ---------------------------------------------------------------------------


def test_delete_invite_revokes_code() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        invite = client.post("/v1/invites", headers=_auth(token_a)).json()
        response = client.delete(f"/v1/invites/{invite['code']}", headers=_auth(token_a))

    assert response.status_code == 204


def test_delete_invite_unknown_code_returns_404() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        response = client.delete("/v1/invites/NONEXISTENT", headers=_auth(token_a))

    assert response.status_code == 404
    assert response.json()["code"] == "invite-code-not-found"


@_PRE_ORM
def test_delete_invite_consumed_code_returns_409() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        token_b = _sign_up(client, _PERSON_B)
        invite = client.post("/v1/invites", headers=_auth(token_a)).json()
        client.post(f"/v1/invites/{invite['code']}/accept", headers=_auth(token_b))
        response = client.delete(f"/v1/invites/{invite['code']}", headers=_auth(token_a))

    assert response.status_code == 409
    assert response.json()["code"] == "invite-code-already-consumed"


# ---------------------------------------------------------------------------
# POST /v1/invites/{code}/accept — accept invite (full happy-path cycle)
# ---------------------------------------------------------------------------


@_PRE_ORM
def test_accept_invite_forms_the_pair() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        token_b = _sign_up(client, _PERSON_B)
        invite = client.post("/v1/invites", headers=_auth(token_a)).json()
        response = client.post(f"/v1/invites/{invite['code']}/accept", headers=_auth(token_b))

    assert response.status_code == 201
    body = response.json()
    assert "pair_id" in body
    assert "person_a_id" in body
    assert "person_b_id" in body
    assert "paired_since" in body


def test_accept_unknown_invite_returns_404() -> None:
    with TestClient(app=build()) as client:
        token_b = _sign_up(client, _PERSON_B)
        response = client.post("/v1/invites/NONEXISTENT/accept", headers=_auth(token_b))

    assert response.status_code == 404
    assert response.json()["code"] == "invite-code-not-found"


@_PRE_ORM
def test_accept_consumed_invite_returns_409() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        token_b = _sign_up(client, _PERSON_B)
        invite = client.post("/v1/invites", headers=_auth(token_a)).json()
        client.post(f"/v1/invites/{invite['code']}/accept", headers=_auth(token_b))
        response = client.post(f"/v1/invites/{invite['code']}/accept", headers=_auth(token_b))

    assert response.status_code == 409
    assert response.json()["code"] == "invite-code-already-consumed"


@_PRE_ORM
def test_accept_invite_already_paired_returns_409() -> None:
    person_c = {"name": "Carla Neves", "email": "carla@example.com", "password": "senha-segura-789"}
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        token_b = _sign_up(client, _PERSON_B)
        token_c = _sign_up(client, person_c)
        invite1 = client.post("/v1/invites", headers=_auth(token_a)).json()
        client.post(f"/v1/invites/{invite1['code']}/accept", headers=_auth(token_b))
        invite2 = client.post("/v1/invites", headers=_auth(token_c)).json()
        response = client.post(f"/v1/invites/{invite2['code']}/accept", headers=_auth(token_b))

    assert response.status_code == 409
    assert response.json()["code"] == "already-paired"


def test_accept_invite_without_auth_returns_401() -> None:
    with TestClient(app=build()) as client:
        token_a = _sign_up(client, _PERSON_A)
        invite = client.post("/v1/invites", headers=_auth(token_a)).json()
        response = client.post(f"/v1/invites/{invite['code']}/accept")

    assert response.status_code == 401
