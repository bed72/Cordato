from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class RevokeInviteCodeData:
    """Command input for revoking an invite — the token to kill and who is requesting it."""

    code: str
    requester_id: str
