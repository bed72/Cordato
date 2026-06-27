from __future__ import annotations

import asyncio

from trocado.features.identity.application.data.person_data import PersonData
from trocado.features.identity.application.data.update_email_data import UpdateEmailData
from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.application.interfaces.session_repository_interface import (
    SessionRepositoryInterface,
)
from trocado.features.identity.application.mappers.person_data_mapper import PersonDataMapper
from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject


class UpdateEmailUseCase:
    """Change an authenticated person's own email — guarded by the current password, then swap and re-secure.

    The email is the login identifier, so this is a credential-sensitive act, mirroring `update-password`.
    Identity is re-confirmed by the *current* password *before* anything is touched: a mismatch — or an
    unresolved/non-active requester, which reads alike (no oracle) — rejects with `IncorrectPasswordError`
    and changes nothing. The new email is validated and normalized by `EmailValueObject` (the cheap pure
    check runs first), and re-checked for uniqueness against *other* active people (`EmailAlreadyInUseError`,
    echoing no address; re-saving one's own email is allowed). On success the email is swapped and every
    *other* session of the person purged while the acting one (`current_session_token`) stays live, so a
    stolen or pre-change token stops resolving without logging the acting device out. Only the email and the
    other sessions change — password hash, name, status, id, created_at, and the ledger are untouched.

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

    async def execute(self, data: UpdateEmailData) -> PersonData:
        # Validate + normalize the new email first (pure, cheap) — a malformed email is rejected before any I/O.
        email = EmailValueObject(data.new_email)

        # Resolving the acting person and the email's current holder are independent — issue them together.
        holder, person = await asyncio.gather(
            self._person_repository.find_active_by_email(email),
            self._person_repository.find_active_by_id(data.requester_id),
        )

        # Guard: re-confirm identity before any change. An unknown/non-active id and a wrong current password
        # fail identically — no oracle reveals which. The expensive verify runs after the cheap reads and
        # gates everything below.
        if person is None or not await self._hasher.verify(data.current_password, person.password):
            raise IncorrectPasswordError()

        # A match on the acting person themselves is not a collision — re-saving your own email is allowed.
        # The holder verdict is consulted only past the identity guard, so a wrong password leaks nothing.
        if holder is not None and holder.id != person.id:
            raise EmailAlreadyInUseError()

        person.update_email(email)

        # Persisting the new email and dropping the person's other sessions are mutually independent — issue
        # them together. The acting session (current_session_token) is the one kept alive.
        await asyncio.gather(
            self._person_repository.update(person),
            self._session_repository.purge_for_person_except(person.id, data.current_session_token),
        )

        return PersonDataMapper.to_data(person)
