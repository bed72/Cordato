from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class PartnerProfileData:
    """The cross-context read shape the identity directory returns: an active person's identity.

    Pairing's own vocabulary for "who a partner is" (id + display name), the counterpart of
    `PartnerExpenseData` / `PartnerActiveBudgetData`. A plain carrier — no invariant, no behavior — so a
    `data` shape, not a value object.
    """

    id: str
    name: str
