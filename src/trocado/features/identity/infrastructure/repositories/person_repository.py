from __future__ import annotations

from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject


class PersonRepository(PersonRepositoryInterface):
    """In-memory person store, keyed by id. A stand-in until an ORM-backed adapter replaces it."""

    def __init__(self) -> None:
        self._people: dict[str, PersonEntity] = {}

    async def find_active_by_id(self, person_id: str) -> PersonEntity | None:
        person = self._people.get(person_id)
        return person if person is not None and person.status is PersonStatus.ACTIVE else None

    async def find_active_by_email(self, email: EmailValueObject) -> PersonEntity | None:
        return next(
            (
                person
                for person in self._people.values()
                if person.status is PersonStatus.ACTIVE and person.email == email
            ),
            None,
        )

    async def create(self, person: PersonEntity) -> None:
        self._people[person.id] = person

    async def update(self, person: PersonEntity) -> None:
        # Re-store the mutated active person by id — an in-place account edit; reads continue to surface it.
        self._people[person.id] = person

    async def delete(self, person: PersonEntity) -> None:
        # Re-store the retired person by id: status is now DELETED and the email neutralized, so reads
        # (which surface only active accounts) no longer return it and the freed email reads as available.
        self._people[person.id] = person
