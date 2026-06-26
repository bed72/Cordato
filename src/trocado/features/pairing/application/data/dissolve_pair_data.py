from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class DissolvePairData:
    """Command input for dissolving a pair — who is dissolving their live pair."""

    requester_id: str
