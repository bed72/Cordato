import asyncio
from datetime import UTC, datetime

from trocado.features.pairing.domain.entities.invite_code_entity import InviteCodeEntity
from trocado.features.pairing.infrastructure.repositories.invite_code_repository import (
    InviteCodeRepository,
)

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _code(id: str = "code-1") -> InviteCodeEntity:
    return InviteCodeEntity.create(id=id, creator_id="person-1", code="tok", created_at=_FIXED_NOW)


def test_create_persists_the_code() -> None:
    repository = InviteCodeRepository()

    asyncio.run(repository.create(_code("code-1")))

    assert repository._invite_codes["code-1"].id == "code-1"


def test_create_keeps_codes_keyed_by_id() -> None:
    repository = InviteCodeRepository()

    asyncio.run(repository.create(_code("code-1")))
    asyncio.run(repository.create(_code("code-2")))

    assert set(repository._invite_codes) == {"code-1", "code-2"}
