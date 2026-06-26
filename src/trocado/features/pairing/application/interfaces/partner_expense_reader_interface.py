from __future__ import annotations

from abc import ABC, abstractmethod

from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData


class PartnerExpenseReaderInterface(ABC):
    """Gateway port — a person's live expenses, read in pairing's own terms.

    The couple view unions both partners' expenses, but expenses live in another context. This port
    states the need in pairing's **own** vocabulary — returning `PartnerExpenseData`, never the expenses
    module's entity — so pairing depends only on this abstraction and never imports a sibling feature.
    The adapter that actually reads the ledger lives outside pairing's domain/application: at the
    composition root today (the only layer permitted to know both modules), and a shared-database query
    in `infrastructure/gateways/` once the ORM lands.

    It is a **gateway**, not a repository: it reads data pairing does not own and maps no entity to a
    table of its own.

    Implementors:
        - MUST return only the person's **live** expenses (soft-deleted ones excluded).
        - MUST return an empty list when the person has no live expense, never raise.
    """

    @abstractmethod
    async def list_for_person(self, person_id: str) -> list[PartnerExpenseData]:
        """Return the person's live expenses; empty when there are none."""
        raise NotImplementedError
