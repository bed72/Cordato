from __future__ import annotations

import asyncio

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.features.identity.application.data.person_data import PersonData
from trocado.features.identity.application.data.sign_up_data import SignUpData
from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.application.mappers.person_data_mapper import PersonDataMapper
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


class SignUpUseCase:
    """Sign up a new person: validate input, enforce email uniqueness, hash, persist, return public data."""

    def __init__(
        self,
        clock: ClockInterface,
        hasher: PasswordHasherInterface,
        repository: PersonRepositoryInterface,
        identifier: IdentifierProviderInterface,
    ) -> None:
        self._clock = clock
        self._hasher = hasher
        self._repository = repository
        self._identifier = identifier

    async def execute(self, data: SignUpData) -> PersonData:
        name = NameValueObject(data.name)
        email = EmailValueObject(data.email)
        password = PasswordValueObject(data.password)

        if await self._repository.find_active_by_email(email) is not None:
            raise EmailAlreadyInUseError()

        created_at, identifier, password_hash = await asyncio.gather(
            self._clock.now(),
            self._identifier.generate(),
            self._hasher.hash(password),
        )

        person = PersonEntity.create(
            name=name,
            email=email,
            id=identifier,
            created_at=created_at,
            password=password_hash,
        )
        await self._repository.create(person)

        return PersonDataMapper.to_data(person)
