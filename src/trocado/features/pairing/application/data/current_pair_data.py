from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class CurrentPairData:
    """Read-model of the reader's current pair, told from the reader's side.

    `partner_id` / `partner_name` are the *other* member of the pair, resolved at read-time relative to the
    reader — never stored. `paired_since` is the pair's `created_at`.
    """

    pair_id: str
    partner_id: str
    partner_name: str
    paired_since: datetime
