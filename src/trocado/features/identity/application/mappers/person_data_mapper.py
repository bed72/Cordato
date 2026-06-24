from __future__ import annotations

from trocado.features.identity.application.data.person_data import PersonData
from trocado.features.identity.domain.entities.person_entity import PersonEntity


class PersonDataMapper:
    """Maps a PersonEntity to its public read-model. Deliberately drops the password hash."""

    @staticmethod
    def to_data(person: PersonEntity) -> PersonData:
        return PersonData(
            id=person.id,
            name=person.name.value,
            email=person.email.value,
            status=person.status.value,
            created_at=person.created_at,
        )
