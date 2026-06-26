from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class PairData:
    """Read-model of a formed pair for the caller."""

    id: str
    person_a_id: str
    person_b_id: str
    created_at: datetime
