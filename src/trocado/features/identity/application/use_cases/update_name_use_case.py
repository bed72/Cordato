from __future__ import annotations

from trocado.features.identity.application.data.person_data import PersonData
from trocado.features.identity.application.data.update_name_data import UpdateNameData
from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.application.mappers.person_data_mapper import PersonDataMapper
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject


class UpdateNameUseCase:
    """Update an authenticated person's own display name: validate, resolve, persist.

    The acting identity is the ``requester_id`` resolved upstream from a live session. A requester that
    resolves to no active person fails with ``InvalidSessionError`` (the acting account is no longer valid).
    A name is not a credential, so this edit re-confirms nothing and purges no session: only the name
    changes — the email, password hash, status, id, created_at, sessions, and ledger are untouched.
    """

    def __init__(self, repository: PersonRepositoryInterface) -> None:
        self._repository = repository

    async def execute(self, data: UpdateNameData) -> PersonData:
        # Validate the value object first (pure, cheap) — a malformed name is rejected before any read.
        name = NameValueObject(data.name)

        person = await self._repository.find_active_by_id(data.requester_id)
        if person is None:
            raise InvalidSessionError()

        person.update_name(name)
        await self._repository.update(person)

        return PersonDataMapper.to_data(person)
