from abc import ABC, abstractmethod

from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


class PasswordHasherInterface(ABC):
    """Port for hashing raw passwords. The concrete algorithm lives in an infrastructure adapter."""

    @abstractmethod
    async def hash(self, password: PasswordValueObject) -> str:
        """Hash a raw password, returning the hash string the entity will persist."""
        raise NotImplementedError
