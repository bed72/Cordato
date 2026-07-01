from __future__ import annotations

from trocado.features.pairing.application.data.partner_profile_data import PartnerProfileData
from trocado.features.pairing.application.interfaces.person_reader_interface import PersonReaderInterface
from trocado.features.pairing.infrastructure.gateways.rows.person_row import PersonRow


class PersonReader(PersonReaderInterface):
    """Duplicates the filter ``PersonRepository.find_active_by_id`` applies (active accounts only) over
    pairing's own local rows instead of importing the identity module's entity, enum or repository.

    Pre-ORM this store is never populated from real person data — the same isolated behavior pairing
    already had via its own repository instance; the ORM replaces this with a real query against the
    shared table without ever reintroducing the cross-feature import.
    """

    def __init__(self) -> None:
        self._rows: dict[str, PersonRow] = {}

    async def find_active_profile(self, person_id: str) -> PartnerProfileData | None:
        row = self._rows.get(person_id)
        if row is None or not row.is_active:
            return None
        return PartnerProfileData(id=person_id, name=row.name)
