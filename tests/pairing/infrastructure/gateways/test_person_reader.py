import asyncio

from trocado.features.pairing.application.data.partner_profile_data import PartnerProfileData
from trocado.features.pairing.infrastructure.gateways.person_reader import PersonReader
from trocado.features.pairing.infrastructure.gateways.rows.person_row import PersonRow


def test_find_active_profile_returns_the_active_persons_profile() -> None:
    reader = PersonReader()
    reader._rows = {"person-1": PersonRow(name="Ana", is_active=True)}

    data = asyncio.run(reader.find_active_profile("person-1"))

    assert data == PartnerProfileData(id="person-1", name="Ana")


def test_find_active_profile_returns_none_for_inactive_or_unknown() -> None:
    reader = PersonReader()
    reader._rows = {"person-1": PersonRow(name="Ana", is_active=False)}

    assert asyncio.run(reader.find_active_profile("person-1")) is None
    assert asyncio.run(reader.find_active_profile("ghost")) is None
