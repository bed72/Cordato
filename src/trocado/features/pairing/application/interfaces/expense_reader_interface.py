from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date
from decimal import Decimal

from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData


class ExpenseReaderInterface(ABC):
    """Gateway port — a partner's expense amounts and live expenses, read in pairing's own terms.

    ``SpendReader`` (core) needs amounts to compute a partner's total spend, and the couple view needs a
    partner's live expenses — but expenses live in another context. This port states both needs in
    pairing's **own** vocabulary — a bare list of amounts, and ``PartnerExpenseData``, never the expenses
    module's entity — so pairing depends only on this abstraction and never imports a sibling feature.
    The adapter that actually reads the ledger lives in ``infrastructure/gateways/``: a local stand-in
    today, a shared-database query once the ORM lands.

    It is a **gateway**, not a repository: it reads data pairing does not own and maps no entity to a
    table of its own.

    Implementors:
        - MUST return only the person's **live** expenses (soft-deleted ones excluded) for both methods.
        - MUST return an empty list when there are none, never raise.
    """

    @abstractmethod
    async def find_amounts_in_range(self, person_id: str, start: date, end: date) -> list[Decimal]:
        """Return the person's live expense amounts within ``[start, end]`` (inclusive)."""
        raise NotImplementedError

    @abstractmethod
    async def list_live_for_person(self, person_id: str) -> list[PartnerExpenseData]:
        """Return the person's live expenses; empty when there are none."""
        raise NotImplementedError
