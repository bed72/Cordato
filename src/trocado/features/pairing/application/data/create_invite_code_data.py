from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class CreateInviteCodeData:
    """Command input for minting an invite code — only who is creating it."""

    creator_id: str
