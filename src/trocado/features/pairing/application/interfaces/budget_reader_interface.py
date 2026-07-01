from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date

from trocado.features.pairing.application.data.active_budget_reading_data import ActiveBudgetReadingData


class BudgetReaderInterface(ABC):
    """Gateway port — a partner's active budget for a day, read in pairing's own terms.

    ``PartnerBudgetReader`` needs a partner's active budget to build the couple budget, but budgets live
    in another context. This port states the need in pairing's **own** vocabulary — ``ActiveBudgetReadingData``,
    never the budgeting module's entity — so pairing depends only on this abstraction and never imports a
    sibling feature. The adapter that actually reads the budget lives in ``infrastructure/gateways/``: a
    local stand-in today, a shared-database query once the ORM lands.

    It is a **gateway**, not a repository: it reads data pairing does not own and maps no entity to a
    table of its own.

    Implementors:
        - MUST return the person's active budget for ``day`` when one exists (live, range contains ``day``).
        - MUST return ``None`` when there is none — never raise.
    """

    @abstractmethod
    async def find_active_for_person(self, person_id: str, day: date) -> ActiveBudgetReadingData | None:
        """Return the person's active budget for ``day``, or ``None`` when there is none."""
        raise NotImplementedError
