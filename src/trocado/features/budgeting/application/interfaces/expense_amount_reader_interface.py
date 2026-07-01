from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date
from decimal import Decimal


class ExpenseAmountReaderInterface(ABC):
    """Gateway port — amounts spent within an inclusive date range, read in budgeting's own terms.

    ``SpendReader`` (core) needs amounts to compute a person's total spend, but expenses live in another
    context. This port states the need in budgeting's **own** vocabulary — a bare list of amounts, never
    the expenses module's entity — so budgeting depends only on this abstraction and never imports a
    sibling feature. The adapter that actually reads the ledger lives in
    ``infrastructure/gateways/``: a local stand-in today, a shared-database query once the ORM lands.

    It is a **gateway**, not a repository: it reads data budgeting does not own and maps no entity to a
    table of its own.

    Implementors:
        - MUST return only the person's **live** expenses (soft-deleted ones excluded) within
          ``[start, end]`` (inclusive).
        - MUST return an empty list when there are none, never raise.
    """

    @abstractmethod
    async def find_amounts_in_range(self, person_id: str, start: date, end: date) -> list[Decimal]:
        """Return the person's live expense amounts within ``[start, end]`` (inclusive)."""
        raise NotImplementedError
