import asyncio
from unittest.mock import AsyncMock, MagicMock

import pytest

from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError
from trocado.features.identity.infrastructure.http.providers.current_person_provider import CurrentPersonProvider


def _make_provider(authorization: str | None, validate_session: AsyncMock) -> CurrentPersonProvider:
    request = MagicMock()
    request.headers = {"Authorization": authorization} if authorization else {}
    return CurrentPersonProvider(request, validate_session)


def test_missing_authorization_header_raises_invalid_session() -> None:
    validate_session = AsyncMock()
    provider = _make_provider(None, validate_session)

    with pytest.raises(InvalidSessionError):
        asyncio.run(provider.data())

    validate_session.execute.assert_not_called()


def test_non_bearer_authorization_raises_invalid_session() -> None:
    validate_session = AsyncMock()
    provider = _make_provider("Basic dXNlcjpwYXNz", validate_session)

    with pytest.raises(InvalidSessionError):
        asyncio.run(provider.data())

    validate_session.execute.assert_not_called()


def test_bearer_without_token_raises_invalid_session() -> None:
    validate_session = AsyncMock()
    validate_session.execute = AsyncMock(side_effect=InvalidSessionError())
    provider = _make_provider("Bearer ", validate_session)

    with pytest.raises(InvalidSessionError):
        asyncio.run(provider.data())


def test_valid_bearer_delegates_to_validate_session_and_returns_person() -> None:
    from datetime import UTC, datetime

    from trocado.features.identity.application.data.person_data import PersonData

    person = PersonData(
        id="pid-1",
        name="Ana",
        status="active",
        email="ana@example.com",
        created_at=datetime(2026, 1, 1, tzinfo=UTC),
    )
    validate_session = AsyncMock()
    validate_session.execute = AsyncMock(return_value=person)
    provider = _make_provider("Bearer my-token-abc", validate_session)

    result = asyncio.run(provider.data())

    validate_session.execute.assert_awaited_once_with("my-token-abc")
    assert result == person
