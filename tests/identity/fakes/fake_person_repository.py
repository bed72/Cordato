from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject


class FakePersonRepository(PersonRepositoryInterface):
    """In-memory test double. Stores people in a list; reads see only active accounts."""

    def __init__(self, *people: PersonEntity) -> None:
        self.people: list[PersonEntity] = list(people)

    async def find_active_by_id(self, person_id: str) -> PersonEntity | None:
        return next(
            (person for person in self.people if person.status is PersonStatus.ACTIVE and person.id == person_id),
            None,
        )

    async def find_active_by_email(self, email: EmailValueObject) -> PersonEntity | None:
        return next(
            (person for person in self.people if person.status is PersonStatus.ACTIVE and person.email == email),
            None,
        )

    async def create(self, person: PersonEntity) -> None:
        self.people.append(person)

    async def update(self, person: PersonEntity) -> None:
        self.people = [person if existing.id == person.id else existing for existing in self.people]

    async def delete(self, person: PersonEntity) -> None:
        self.people = [person if existing.id == person.id else existing for existing in self.people]
