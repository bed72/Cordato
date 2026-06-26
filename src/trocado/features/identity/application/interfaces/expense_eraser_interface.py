from __future__ import annotations

from abc import ABC, abstractmethod


class ExpenseEraserInterface(ABC):
    """Identity's own port for physically erasing a person's expenses — an anti-corruption seam, not a coupling.

    Why it exists: deleting an account must cascade-erase the person's expenses, a fact owned by the
    ``expenses`` context. The modular monolith forbids an ``identity -> expenses`` import, so identity
    depends on this abstraction in its own vocabulary; the concrete adapter that bridges to expenses is
    wired at the composition root. Mirrors how ``pairing`` consumes identity through its reader ports.

    Implementors (adapters wired at the composition root):
        - MUST **physically** delete every expense the person owns — live and soft-deleted alike — leaving
          no row behind. This is account deletion's hard cascade, not a day-to-day soft-delete.
        - MUST touch no other person's expenses.
        - MUST be safe to call when the person owns no expense (a no-op).
    """

    @abstractmethod
    async def erase_for_person(self, person_id: str) -> None:
        """Physically erase all of the given person's expenses."""
        raise NotImplementedError
