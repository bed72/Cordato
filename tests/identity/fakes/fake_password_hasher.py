from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


class FakePasswordHasher(PasswordHasherInterface):
    """Deterministic test hasher: a recognizable, non-plaintext marker instead of a real Argon2 digest."""

    async def hash(self, password: PasswordValueObject) -> str:
        return f"hashed::{password.value}"

    async def verify(self, password: PasswordValueObject, hash: str) -> bool:
        return hash == f"hashed::{password.value}"
