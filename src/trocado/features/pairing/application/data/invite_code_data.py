from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class InviteCodeData:
    """Read-model of an invite code for the caller."""

    id: str
    code: str
    creator_id: str
    created_at: datetime
    expires_at: datetime
    consumed_at: datetime | None
