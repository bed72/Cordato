from abc import ABC, abstractmethod

from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject


class PersonRepositoryInterface(ABC):
    """Port for persisting and looking up people. Adapters live in infrastructure."""

    @abstractmethod
    async def find_active_by_email(self, email: EmailValueObject) -> PersonEntity | None:
        """Return the active person holding this email, or None. Excludes non-active accounts."""
        raise NotImplementedError

    @abstractmethod
    async def create(self, person: PersonEntity) -> None:
        """Persist a new person."""
        raise NotImplementedError
