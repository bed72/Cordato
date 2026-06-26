from __future__ import annotations

import asyncio

from trocado.features.identity.application.data.update_password_data import UpdatePasswordData
from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.application.interfaces.session_repository_interface import (
    SessionRepositoryInterface,
)
from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError


class UpdatePasswordUseCase:
    """Rotate an authenticated person's own password — guarded by the current password, then swap the hash.

    Identity is re-confirmed by the *current* password *before* anything is touched, exactly like
    `delete-account`: a mismatch — or an unresolved/non-active requester, which reads alike (no oracle) —
    rejects with `IncorrectPasswordError` and changes nothing. Only past that guard is the new password
    hashed (never pay for hashing a request the guard would reject) and stored, and every *other* session of
    the person purged while the acting one (`current_session_token`) stays live, so a stolen or pre-rotation
    token stops resolving without logging the acting device out. The two passwords arrive already
    policy-validated as `PasswordValueObject`s. Nothing secret leaves: the use case returns nothing.

    Atomicity is the contract; at the in-memory stage there is no transaction manager, so the guard runs
    strictly first (the only pre-mutation failure leaves everything intact) and the indivisible boundary
    arrives with the ORM, behind these same ports.
    """

    def __init__(
        self,
        hasher: PasswordHasherInterface,
        person_repository: PersonRepositoryInterface,
        session_repository: SessionRepositoryInterface,
    ) -> None:
        self._hasher = hasher
        self._person_repository = person_repository
        self._session_repository = session_repository

    async def execute(self, data: UpdatePasswordData) -> None:
        # Guard first: re-confirm identity before any change. An unknown/non-active id and a wrong current
        # password fail identically — no oracle reveals which.
        person = await self._person_repository.find_active_by_id(data.requester_id)
        if person is None or not await self._hasher.verify(data.current_password, person.password):
            raise IncorrectPasswordError()

        # Only past the guard do we pay for hashing the new password.
        new_hash = await self._hasher.hash(data.new_password)
        person.update_password(new_hash)

        # Persisting the new hash and dropping the person's other sessions are mutually independent — issue
        # them together. The acting session (current_session_token) is the one kept alive.
        await asyncio.gather(
            self._person_repository.update(person),
            self._session_repository.purge_for_person_except(person.id, data.current_session_token),
        )
