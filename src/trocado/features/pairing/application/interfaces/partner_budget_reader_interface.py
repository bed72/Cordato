from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date

from trocado.features.pairing.application.data.partner_active_budget_data import (
    PartnerActiveBudgetData,
)


class PartnerBudgetReaderInterface(ABC):
    """Gateway port — a person's active budget for a day, read in pairing's own terms.

    The couple budget combines both partners' active budgets, but budgets live in another context. This
    port states the need in pairing's **own** vocabulary — returning `PartnerActiveBudgetData`, never the
    budgeting module's `ActiveBudgetVirtualObject` — so pairing depends only on this abstraction and never
    imports a sibling feature. The adapter that actually reads the budget (delegating to budgeting's
    `GetActiveBudgetUseCase`) lives outside pairing's domain/application: at the composition root today (the
    only layer permitted to know both modules), and a shared-database query in `infrastructure/gateways/`
    once the ORM lands.

    It is a **gateway**, not a repository: it reads data pairing does not own and maps no entity to a table
    of its own.

    Implementors:
        - MUST return the person's active budget for ``day`` when one exists (live, range contains ``day``).
        - MUST return ``None`` when the person has no active budget for ``day`` — never raise, and never
          fabricate a "No budget" bucket (that is a separate concern).
    """

    @abstractmethod
    async def active_for_person(self, person_id: str, day: date) -> PartnerActiveBudgetData | None:
        """Return the person's active budget for ``day``, or ``None`` when there is none."""
        raise NotImplementedError
