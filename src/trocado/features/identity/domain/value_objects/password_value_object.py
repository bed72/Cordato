from __future__ import annotations

from dataclasses import dataclass

from trocado.features.identity.domain.errors.weak_password_error import WeakPasswordError

MINIMUM_LENGTH = 8


@dataclass(frozen=True, slots=True, repr=False)
class PasswordValueObject:
    """A raw, policy-checked password. Transient input to the hasher — never persisted.

    Its plaintext is deliberately kept out of `repr` so it cannot leak into logs or tracebacks.
    Note: the value is NOT trimmed — leading/trailing spaces are valid password characters.
    """

    value: str

    def __post_init__(self) -> None:
        if len(self.value) < MINIMUM_LENGTH:
            raise WeakPasswordError(MINIMUM_LENGTH)

    def __repr__(self) -> str:
        return "PasswordValueObject(***)"
