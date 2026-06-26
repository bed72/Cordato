from __future__ import annotations

from abc import ABC, abstractmethod

from trocado.features.budgeting.application.data.ledger_expense_data import LedgerExpenseData


class ExpenseReaderInterface(ABC):
    """Gateway port — a person's live expenses, read in budgeting's own terms.

    The default budget groups the owner's expenses that fall in no live budget, but expenses live in
    another context. This port states the need in budgeting's **own** vocabulary — returning
    ``LedgerExpenseData``, never the expenses module's entity — so budgeting depends only on this
    abstraction and never imports a sibling feature. The adapter that actually reads the ledger lives
    outside budgeting's domain/application: at the composition root today (the only layer permitted to
    know both modules), and a shared-database query in ``infrastructure/gateways/`` once the ORM lands.

    It is distinct from ``SpendReaderInterface`` on purpose: that one returns *a total amount, never an
    expense*, while the default bucket genuinely needs the individual expenses — two needs, two ports.

    It is a **gateway**, not a repository: it reads data budgeting does not own and maps no entity to a
    table of its own.

    Implementors:
        - MUST return only the person's **live** expenses (soft-deleted ones excluded).
        - MUST return an empty list when the person has no live expense, never raise.
    """

    @abstractmethod
    async def list_for_person(self, person_id: str) -> list[LedgerExpenseData]:
        """Return the person's live expenses; empty when there are none."""
        raise NotImplementedError
