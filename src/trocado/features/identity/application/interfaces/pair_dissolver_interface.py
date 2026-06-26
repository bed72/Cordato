from __future__ import annotations

from abc import ABC, abstractmethod


class PairDissolverInterface(ABC):
    """Identity's own port for dissolving a person's live pair as a consequence of account deletion.

    Why it exists: deleting an account takes the shared view down, but the pair is owned by the ``pairing``
    context. The modular monolith forbids an ``identity -> pairing`` import, so identity depends on this
    abstraction in its own vocabulary; the concrete adapter that bridges to pairing's
    ``find_active_by_person`` + ``dissolve`` is wired at the composition root.

    Unlike the standalone dissolve use case, this seam is **idempotent**: deleting an account must succeed
    whether or not the person happened to be paired, so "in no live pair" is a no-op here, never an error.

    Implementors (adapters wired at the composition root):
        - MUST dissolve (soft-delete) the person's live pair if one exists.
        - MUST be a no-op — never raise — when the person is in no live pair.
        - MUST touch only the pair's soft-delete; no budget or expense of either partner is moved or erased.
    """

    @abstractmethod
    async def dissolve_for_person(self, person_id: str) -> None:
        """Dissolve the given person's live pair if one exists; otherwise do nothing."""
        raise NotImplementedError
