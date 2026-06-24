from __future__ import annotations

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)
from trocado.features.identity.application.data.create_person_data import CreatePersonData
from trocado.features.identity.application.data.person_data import PersonData
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


class CreatePersonUseCase:
    """Create a new person: validate input, enforce email uniqueness, hash, persist, return public data."""

    def __init__(
        self,
        repository: PersonRepositoryInterface,
        hasher: PasswordHasherInterface,
        identifier_provider: IdentifierProviderInterface,
        clock: ClockInterface,
    ) -> None:
        self._repository = repository
        self._hasher = hasher
        self._identifier_provider = identifier_provider
        self._clock = clock

    async def execute(self, data: CreatePersonData) -> PersonData:
        name = NameValueObject(data.name)
        email = EmailValueObject(data.email)
        password = PasswordValueObject(data.password)

        if await self._repository.find_active_by_email(email) is not None:
            raise EmailAlreadyInUseError()

        password_hash = await self._hasher.hash(password)
        identifier = await self._identifier_provider.generate()
        created_at = await self._clock.now()

        person = PersonEntity.create(
            id=identifier,
            created_at=created_at,
            name=name,
            email=email,
            password=password_hash,
        )
        await self._repository.create(person)

        return PersonDataMapper.to_data(person)
