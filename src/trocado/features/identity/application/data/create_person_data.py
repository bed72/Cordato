from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class CreatePersonData:
    """Command input for creating a person — raw values straight from the caller."""

    name: str
    email: str
    password: str
