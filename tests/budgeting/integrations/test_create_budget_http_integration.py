from decimal import Decimal

from litestar.testing import TestClient

from trocado.core.infrastructure.http.app import build

_BODY = {
    "amount": "500.00",
    "start_date": "2026-06-01",
    "end_date": "2026-06-30",
    "note": "  mercado  ",
}


def test_post_budgets_creates_a_budget() -> None:
    """The real route, wired through the composition root, answers 201 with the created budget read-model."""
    with TestClient(app=build()) as client:
        response = client.post("/v1/budgets", json=_BODY)

    assert response.status_code == 201
    body = response.json()
    assert len(body["id"]) == 36  # a canonical uuid7 string from the real identifier gateway
    assert body["note"] == "mercado"  # the domain trims the note
    assert Decimal(str(body["amount"])) == Decimal("500.00")
    assert body["start_date"] == "2026-06-01"
    assert body["end_date"] == "2026-06-30"


def test_a_malformed_body_is_rejected_before_the_use_case() -> None:
    """A body missing a required field is rejected at the boundary (client error), never reaching the use case."""
    with TestClient(app=build()) as client:
        response = client.post("/v1/budgets", json={"start_date": "2026-06-01", "end_date": "2026-06-30"})

    assert 400 <= response.status_code < 500


def test_the_shared_singleton_persists_across_requests_within_a_run() -> None:
    """A second overlapping create, on the same app, is rejected — proving the repository is a shared singleton.

    The clean 409 framing belongs to the deferred error-mapping change; here it suffices that the second request
    does not succeed, because the use case observed the first budget persisted in the app-scoped repository.
    """
    with TestClient(app=build(), raise_server_exceptions=False) as client:
        first = client.post("/v1/budgets", json=_BODY)
        second = client.post("/v1/budgets", json=_BODY)

    assert first.status_code == 201
    assert second.status_code >= 400
