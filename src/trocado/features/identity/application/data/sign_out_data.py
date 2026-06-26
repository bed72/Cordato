from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class SignOutData:
    """Command input for signing out — the bearer token whose session is to be revoked."""

    token: str
