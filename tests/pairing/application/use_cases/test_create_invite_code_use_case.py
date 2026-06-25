import asyncio
from datetime import UTC, datetime, timedelta

from tests.core.fakes.fake_clock import FakeClock
from tests.core.fakes.fake_identifier_provider import FakeIdentifierProvider
from tests.pairing.fakes.fake_invite_code_repository import FakeInviteCodeRepository
from tests.pairing.fakes.fake_token_generator import FakeTokenGenerator
from trocado.features.pairing.application.data.create_invite_code_data import CreateInviteCodeData
from trocado.features.pairing.application.use_cases.create_invite_code_use_case import (
    CreateInviteCodeUseCase,
)

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _build_use_case(
    identifier: str = "code-1",
    repository: FakeInviteCodeRepository | None = None,
    *tokens: str,
) -> tuple[CreateInviteCodeUseCase, FakeInviteCodeRepository]:
    repository = repository or FakeInviteCodeRepository()
    use_case = CreateInviteCodeUseCase(
        repository=repository,
        clock=FakeClock(_FIXED_NOW),
        token_generator=FakeTokenGenerator(*tokens),
        identifier=FakeIdentifierProvider(identifier),
    )

    return use_case, repository


def _command(creator_id: str = "person-1") -> CreateInviteCodeData:
    return CreateInviteCodeData(creator_id=creator_id)


def test_mints_a_code_for_the_creator() -> None:
    use_case, repository = _build_use_case("new-id", None, "the-token")

    data = asyncio.run(use_case.execute(_command(creator_id="person-7")))

    assert data.id == "new-id"
    assert data.code == "the-token"
    assert data.creator_id == "person-7"
    assert data.created_at == _FIXED_NOW
    assert len(repository.invite_codes) == 1
    assert repository.invite_codes[0].id == "new-id"


def test_new_code_starts_unconsumed() -> None:
    use_case, _ = _build_use_case()

    data = asyncio.run(use_case.execute(_command()))

    assert data.consumed_at is None


def test_expiry_is_derived_from_the_clock() -> None:
    use_case, _ = _build_use_case()

    data = asyncio.run(use_case.execute(_command()))

    assert data.expires_at == _FIXED_NOW + timedelta(days=1)


def test_token_comes_from_the_generator() -> None:
    use_case, _ = _build_use_case("code-1", None, "from-generator")

    data = asyncio.run(use_case.execute(_command()))

    assert data.code == "from-generator"


def test_two_codes_get_distinct_tokens() -> None:
    use_case, repository = _build_use_case("code-1", None, "token-a", "token-b")

    asyncio.run(use_case.execute(_command()))
    asyncio.run(use_case.execute(_command()))

    assert [code.code for code in repository.invite_codes] == ["token-a", "token-b"]


def test_id_and_created_at_come_from_ports() -> None:
    use_case, repository = _build_use_case("from-port", None)

    data = asyncio.run(use_case.execute(_command()))

    assert data.id == "from-port"
    assert data.created_at == _FIXED_NOW
    assert repository.invite_codes[0].created_at == _FIXED_NOW
