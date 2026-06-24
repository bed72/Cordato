from __future__ import annotations

import asyncio

from argon2 import PasswordHasher as Argon2PasswordHasher

from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


class PasswordHasher(PasswordHasherInterface):
    """Argon2-backed hasher. The hashing call is CPU-bound and synchronous, so it runs off the event loop."""

    def __init__(self) -> None:
        self._hasher = Argon2PasswordHasher()

    async def hash(self, password: PasswordValueObject) -> str:
        return await asyncio.to_thread(self._hasher.hash, password.value)
