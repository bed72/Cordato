from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class PersonData:
    """Read-model of a person for the caller. Carries no password field of any kind."""

    id: str
    name: str
    email: str
    status: str
    created_at: datetime
