from __future__ import annotations

from abc import ABC, abstractmethod


class BudgetEraserInterface(ABC):
    """Identity's own port for physically erasing a person's budgets — an anti-corruption seam, not a coupling.

    Why it exists: deleting an account must cascade-erase the person's budgets, a fact owned by the
    ``budgeting`` context. The modular monolith forbids an ``identity -> budgeting`` import, so identity
    does **not** reach into another module; it depends on this abstraction, in its own vocabulary, and the
    concrete adapter that bridges to budgeting is wired at the composition root — the only layer permitted
    to know both modules. This mirrors how ``pairing`` consumes identity through ``PersonDirectoryInterface``.

    Implementors (adapters wired at the composition root):
        - MUST **physically** delete every budget the person owns — live and soft-deleted alike — leaving
          no row behind. This is account deletion's hard cascade, not a day-to-day soft-delete.
        - MUST touch no other person's budgets.
        - MUST be safe to call when the person owns no budget (a no-op).
    """

    @abstractmethod
    async def erase_for_person(self, person_id: str) -> None:
        """Physically erase all of the given person's budgets."""
        raise NotImplementedError
