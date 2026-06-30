from __future__ import annotations

from collections.abc import Awaitable, Callable

from trocado.features.pairing.application.data.partner_profile_data import PartnerProfileData
from trocado.features.pairing.application.interfaces.person_directory_interface import PersonDirectoryInterface


class PersonDirectory(PersonDirectoryInterface):
    def __init__(self, fetch_profile: Callable[[str], Awaitable[PartnerProfileData | None]]) -> None:
        self._fetch_profile = fetch_profile

    async def is_active(self, person_id: str) -> bool:
        return await self._fetch_profile(person_id) is not None

    async def find_active_profile(self, person_id: str) -> PartnerProfileData | None:
        return await self._fetch_profile(person_id)
