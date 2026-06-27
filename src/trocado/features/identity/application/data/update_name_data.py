from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class UpdateNameData:
    """Command input for updating a display name — who is acting, and the new name (raw value)."""

    name: str
    requester_id: str
