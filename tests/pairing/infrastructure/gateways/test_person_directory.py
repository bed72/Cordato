import asyncio

from trocado.features.pairing.application.data.partner_profile_data import PartnerProfileData
from trocado.features.pairing.infrastructure.gateways.person_directory import PersonDirectory

_PROFILE = PartnerProfileData(id="person-1", name="Ana Lima")


async def _active(person_id: str) -> PartnerProfileData | None:
    return _PROFILE if person_id == "person-1" else None


def test_is_active_returns_true_when_profile_found() -> None:
    directory = PersonDirectory(_active)
    assert asyncio.run(directory.is_active("person-1")) is True


def test_is_active_returns_false_when_profile_not_found() -> None:
    directory = PersonDirectory(_active)
    assert asyncio.run(directory.is_active("unknown")) is False


def test_find_active_profile_returns_profile_when_found() -> None:
    directory = PersonDirectory(_active)
    result = asyncio.run(directory.find_active_profile("person-1"))
    assert result == _PROFILE


def test_find_active_profile_returns_none_when_not_found() -> None:
    directory = PersonDirectory(_active)
    assert asyncio.run(directory.find_active_profile("unknown")) is None


def test_fetch_profile_callable_receives_correct_person_id() -> None:
    calls: list[str] = []

    async def fake_fetch(person_id: str) -> PartnerProfileData | None:
        calls.append(person_id)
        return None

    directory = PersonDirectory(fake_fetch)
    asyncio.run(directory.find_active_profile("person-42"))
    assert calls == ["person-42"]
