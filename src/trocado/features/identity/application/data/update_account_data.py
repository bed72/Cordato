from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class UpdateAccountData:
    """Command input for updating an account — who is acting, and the new name and email (raw values)."""

    name: str
    email: str
    requester_id: str
