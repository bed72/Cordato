from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class AcceptInviteCodeData:
    """Command input for redeeming an invite — the token and who is accepting it."""

    code: str
    accepter_id: str
