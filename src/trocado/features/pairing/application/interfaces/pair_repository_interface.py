from __future__ import annotations

from abc import ABC, abstractmethod

from trocado.features.pairing.domain.entities.pair_entity import PairEntity


class PairRepositoryInterface(ABC):
    """Port for persisting and looking up pairs.

    Soft-delete is the repository's responsibility: ``find_active_by_person`` surfaces only a *live* pair
    (``deleted_at`` null), so dissolved pairs in a person's history never block a new pairing. A person is
    in at most one live pair, so the lookup returns a single optional entity.

    Implementors (adapters in ``infrastructure/repositories/``):
        - MUST accept and return domain ``PairEntity`` objects.
        - MUST exclude dissolved (soft-deleted) pairs from ``find_active_by_person``.
    """

    @abstractmethod
    async def find_active_by_person(self, person_id: str) -> PairEntity | None:
        """Return the person's live pair, or ``None`` if they are in no live pair."""
        raise NotImplementedError

    @abstractmethod
    async def create(self, pair: PairEntity) -> None:
        """Persist a newly formed pair."""
        raise NotImplementedError
