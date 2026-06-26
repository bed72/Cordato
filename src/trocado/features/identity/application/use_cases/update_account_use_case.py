from __future__ import annotations

import asyncio

from trocado.features.identity.application.data.person_data import PersonData
from trocado.features.identity.application.data.update_account_data import UpdateAccountData
from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.application.mappers.person_data_mapper import PersonDataMapper
from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject


class UpdateAccountUseCase:
    """Update an authenticated person's own account: validate, re-enforce email uniqueness, persist.

    The acting identity is the ``requester_id`` resolved upstream from a live session. A requester that
    resolves to no active person fails with ``InvalidSessionError`` (the acting account is no longer
    valid). The email-uniqueness invariant is re-enforced against the *other* active people: a normalized
    email already held by a different active person rejects with ``EmailAlreadyInUseError``, while
    re-saving the person's own current email is allowed. Only the name and email change — the password
    hash, status, id, created_at, and the ledger are untouched.
    """

    def __init__(self, repository: PersonRepositoryInterface) -> None:
        self._repository = repository

    async def execute(self, data: UpdateAccountData) -> PersonData:
        # Validate the value objects first (pure, cheap) — a malformed email/name is rejected before any read.
        name = NameValueObject(data.name)
        email = EmailValueObject(data.email)

        # Resolving the acting person and the email's current holder are independent — issue them together.
        person, holder = await asyncio.gather(
            self._repository.find_active_by_id(data.requester_id),
            self._repository.find_active_by_email(email),
        )

        if person is None:
            raise InvalidSessionError()

        # A match on the acting person themselves is not a collision — re-saving your own email is allowed.
        if holder is not None and holder.id != person.id:
            raise EmailAlreadyInUseError()

        person.update_account(name=name, email=email)
        await self._repository.update(person)

        return PersonDataMapper.to_data(person)
