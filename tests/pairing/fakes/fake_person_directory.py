from trocado.features.pairing.application.interfaces.person_directory_interface import (
    PersonDirectoryInterface,
)


class FakePersonDirectory(PersonDirectoryInterface):
    """Reports active people from a known set; everyone else reads as inactive.

    Defaults to treating every queried person as active; pass an explicit set to mark some inactive.
    """

    def __init__(self, active_ids: set[str] | None = None) -> None:
        self._active_ids = active_ids
        self.queried_ids: list[str] = []

    async def is_active(self, person_id: str) -> bool:
        self.queried_ids.append(person_id)
        if self._active_ids is None:
            return True
        return person_id in self._active_ids
