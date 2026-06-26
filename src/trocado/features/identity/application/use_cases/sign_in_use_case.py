from __future__ import annotations

import asyncio

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.features.identity.application.data.session_data import SessionData
from trocado.features.identity.application.data.sign_in_data import SignInData
from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.application.interfaces.session_repository_interface import (
    SessionRepositoryInterface,
)
from trocado.features.identity.application.interfaces.token_generator_interface import (
    TokenGeneratorInterface,
)
from trocado.features.identity.application.mappers.session_data_mapper import SessionDataMapper
from trocado.features.identity.domain.entities.session_entity import SessionEntity
from trocado.features.identity.domain.errors.invalid_credentials_error import InvalidCredentialsError
from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError
from trocado.features.identity.domain.errors.weak_password_error import WeakPasswordError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject
from trocado.features.identity.domain.virtual_objects.authenticated_session_virtual_object import (
    AuthenticatedSessionVirtualObject,
)

# A real Argon2 digest of a throwaway secret, used ONLY on the not-found path so that *every* sign-in pays
# exactly one verify. Without it, an unknown email would return faster than a wrong password and that timing
# gap would itself reveal whether the email exists. Its result is always discarded — it authenticates no one.
# Regenerate if the hasher's Argon2 parameters change materially (the cost must stay comparable to a real one).
_DECOY_HASH = "$argon2id$v=19$m=65536,t=3,p=4$k1hgbldg8ljpxdmJuLmHWg$gHdBhBY09Aev0XcDQ+Ezm2BfR6JhDwbX1AhKFSBZWp8"


class SignInUseCase:
    """Verify a credential and, on success, issue a session — the `sign_in` half of identity.

    Two security rules shape the verification, both serving the same end (no account enumeration):
      - **One generic failure.** A malformed email, an unknown/inactive email, and a wrong password all
        raise `InvalidCredentialsError` — the caller can never tell which half was wrong.
      - **Uniform timing.** A verify runs on *every* attempt; when no person is found, it runs against a
        constant decoy hash. This deliberately inverts the usual "cheap guard before the expensive call":
        here the hash cost is paid on purpose, so response time never betrays the email's existence.

    Only **past a successful verify** is a session issued: a fresh `SessionEntity` with an opaque CSPRNG
    token and a fixed expiry, persisted, then returned as `SessionData` (the token + expiry + the person).
    A failed sign-in issues nothing. The raw password lives only as a transient value object and is never
    persisted, logged, or echoed.
    """

    def __init__(
        self,
        clock: ClockInterface,
        hasher: PasswordHasherInterface,
        identifier: IdentifierProviderInterface,
        token_generator: TokenGeneratorInterface,
        person_repository: PersonRepositoryInterface,
        session_repository: SessionRepositoryInterface,
    ) -> None:
        self._clock = clock
        self._hasher = hasher
        self._identifier = identifier
        self._token_generator = token_generator
        self._person_repository = person_repository
        self._session_repository = session_repository

    async def execute(self, data: SignInData) -> SessionData:
        # Building the value objects validates the input. In sign-in a malformed email or a too-short
        # password must look exactly like a wrong credential — so collapse those into the generic error
        # instead of letting InvalidEmailError/WeakPasswordError leak which factor was malformed.
        try:
            email = EmailValueObject(data.email)
            password = PasswordValueObject(data.password)
        except (InvalidEmailError, WeakPasswordError) as error:
            raise InvalidCredentialsError() from error

        # Sequential: the verify depends on which person (if any) the email resolves to — no gather.
        person = await self._person_repository.find_active_by_email(email)

        # Always verify, even with no person, against the decoy — equalizing timing. Authenticate only when
        # a real person was found AND their hash verifies; the decoy branch can only ever fail.
        verified = await self._hasher.verify(password, person.password if person is not None else _DECOY_HASH)
        if person is None or not verified:
            raise InvalidCredentialsError()

        # Past the guard: issue the session. The three reads are mutually independent — gather them.
        created_at, id, token = await asyncio.gather(
            self._clock.now(),
            self._identifier.generate(),
            self._token_generator.generate(),
        )
        session = SessionEntity.create(id=id, token=token, person_id=person.id, created_at=created_at)
        await self._session_repository.create(session)

        return SessionDataMapper.to_data(AuthenticatedSessionVirtualObject(session=session, person=person))
