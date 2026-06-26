from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class SignUpData:
    """Command input for signing up a new person — raw values straight from the caller."""

    name: str
    email: str
    password: str
