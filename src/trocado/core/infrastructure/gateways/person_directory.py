from __future__ import annotations

from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.pairing.application.data.partner_profile_data import PartnerProfileData
from trocado.features.pairing.application.interfaces.person_directory_interface import (
    PersonDirectoryInterface,
)


class PersonDirectory(PersonDirectoryInterface):
    """Cross-feature bridge: resolves people for the pairing context through identity's repository.

    Lives in core/infrastructure because it imports from two feature packages simultaneously.
    Pre-ORM: replaced by a shared-database query once persistence lands.
    """

    def __init__(self, person_repository: PersonRepositoryInterface) -> None:
        self._person_repository = person_repository

    async def is_active(self, person_id: str) -> bool:
        person = await self._person_repository.find_active_by_id(person_id)
        return person is not None

    async def find_active_profile(self, person_id: str) -> PartnerProfileData | None:
        person = await self._person_repository.find_active_by_id(person_id)
        if person is None:
            return None
        return PartnerProfileData(id=person.id, name=person.name.value)
