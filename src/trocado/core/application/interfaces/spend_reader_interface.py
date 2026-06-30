from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject


class SpendReaderInterface(ABC):
    """Gateway port — how much a person has spent within an inclusive date range.

    Budgeting needs spend to enrich the active budget, but spend lives in another context. This port
    states the need in budgeting's **own** terms — a total amount, never an expense — so the module
    depends only on this abstraction and on the core, never on a sibling feature. The adapter that
    actually sums the underlying ledger lives outside budgeting's domain/application: at the composition
    root today, and a shared-database query in ``infrastructure/gateways/`` once the ORM lands.

    It is a **gateway**, not a repository: it reads data budgeting does not own and returns a core value
    object, mapping no entity to a table of its own.
    """

    @abstractmethod
    async def total_spent(self, person_id: str, start: date, end: date) -> MoneyValueObject:
        """Return the person's total spend within ``[start, end]`` (inclusive); zero when none."""
        raise NotImplementedError
