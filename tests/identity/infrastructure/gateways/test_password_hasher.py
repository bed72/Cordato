import asyncio

from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject
from trocado.features.identity.infrastructure.gateways.password_hasher import PasswordHasher


def test_hash_differs_from_plaintext_and_carries_argon2_marker() -> None:
    digest = asyncio.run(PasswordHasher().hash(PasswordValueObject("supersecret")))

    assert digest != "supersecret"
    assert "supersecret" not in digest
    # Argon2 PHC string marker — proves the real algorithm ran, with no lib name leaking into the class.
    assert digest.startswith("$argon2")


def test_hash_is_salted_so_same_password_yields_distinct_digests() -> None:
    hasher = PasswordHasher()
    password = PasswordValueObject("supersecret")

    first = asyncio.run(hasher.hash(password))
    second = asyncio.run(hasher.hash(password))

    assert first != second
