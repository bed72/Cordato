from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


class FakeRecordingPasswordHasher(PasswordHasherInterface):
    """Like the plain fake hasher, but records every hash it was asked to `verify` against.

    Lets a test prove the *timing-equalization* contract: that a sign-in runs exactly one verify on every
    path, against the decoy hash when no person was found. Same `hashed::<plaintext>` scheme as the plain
    fake, so a real stored hash still matches its plaintext while the decoy never does.
    """

    def __init__(self) -> None:
        self.verified_against: list[str] = []

    async def hash(self, password: PasswordValueObject) -> str:
        return f"hashed::{password.value}"

    async def verify(self, password: PasswordValueObject, hash: str) -> bool:
        self.verified_against.append(hash)
        return hash == f"hashed::{password.value}"
