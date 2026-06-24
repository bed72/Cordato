from __future__ import annotations

import re
from dataclasses import dataclass

from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError

_EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


@dataclass(frozen=True, slots=True)
class EmailValueObject:
    """A validated, normalized email address. Always lowercased and trimmed."""

    value: str

    def __post_init__(self) -> None:
        normalized = self.value.strip().lower()
        if not _EMAIL_PATTERN.match(normalized):
            raise InvalidEmailError()
        object.__setattr__(self, "value", normalized)
