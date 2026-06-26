from trocado.features.pairing.application.data.partner_profile_data import PartnerProfileData
from trocado.features.pairing.application.interfaces.person_directory_interface import (
    PersonDirectoryInterface,
)


class FakePersonDirectory(PersonDirectoryInterface):
    """Reports active people, and resolves their profiles, from known sets.

    `is_active` defaults to treating every queried person as active; pass an explicit `active_ids` set to
    mark some inactive. `find_active_profile` resolves names from the `profiles` map (id -> name) and
    returns `None` for anyone absent — seed it to drive the partner-name read.
    """

    def __init__(
        self,
        active_ids: set[str] | None = None,
        profiles: dict[str, str] | None = None,
    ) -> None:
        self._active_ids = active_ids
        self._profiles = profiles or {}
        self.queried_ids: list[str] = []
        self.profile_queried_ids: list[str] = []

    async def is_active(self, person_id: str) -> bool:
        self.queried_ids.append(person_id)
        if self._active_ids is None:
            return True
        return person_id in self._active_ids

    async def find_active_profile(self, person_id: str) -> PartnerProfileData | None:
        self.profile_queried_ids.append(person_id)
        name = self._profiles.get(person_id)
        if name is None:
            return None
        return PartnerProfileData(id=person_id, name=name)
