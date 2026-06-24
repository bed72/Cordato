from __future__ import annotations

from dataclasses import dataclass

from trocado.features.identity.domain.errors.invalid_name_error import InvalidNameError


@dataclass(frozen=True, slots=True)
class NameValueObject:
    """A non-empty name, trimmed of surrounding whitespace."""

    value: str

    def __post_init__(self) -> None:
        normalized = self.value.strip()
        if not normalized:
            raise InvalidNameError()
        object.__setattr__(self, "value", normalized)
