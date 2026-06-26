from __future__ import annotations

import asyncio

import argon2

from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


class PasswordHasher(PasswordHasherInterface):
    """Argon2-backed hasher. The hashing call is CPU-bound and synchronous, so it runs off the event loop."""

    def __init__(self) -> None:
        self._hasher = argon2.PasswordHasher()

    async def hash(self, password: PasswordValueObject) -> str:
        return await asyncio.to_thread(self._hasher.hash, password.value)

    async def verify(self, password: PasswordValueObject, hash: str) -> bool:
        # Argon2's verify is constant-time and raises on mismatch; translate that into a plain bool.
        # CPU-bound, so it runs off the event loop, like hashing.
        try:
            return await asyncio.to_thread(self._hasher.verify, hash, password.value)
        except argon2.exceptions.VerifyMismatchError:
            return False
