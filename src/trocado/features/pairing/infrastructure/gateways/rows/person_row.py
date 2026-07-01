from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class PersonRow:
    """``PersonReader``'s own local storage row — not the identity module's entity or enum."""

    name: str
    is_active: bool
