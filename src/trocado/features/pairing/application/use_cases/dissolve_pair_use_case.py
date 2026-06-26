from __future__ import annotations

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.pairing.application.data.dissolve_pair_data import DissolvePairData
from trocado.features.pairing.application.interfaces.pair_repository_interface import (
    PairRepositoryInterface,
)
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError


class DissolvePairUseCase:
    """Take the shared view down: resolve the requester's live pair and soft-dissolve it.

    The pair is resolved *by the requester*, so a person can only ever dissolve their own live pair —
    authorization is the lookup itself. Only the pair's ``deleted_at`` is touched; every budget and
    expense each partner owns stays intact.
    """

    def __init__(
        self,
        clock: ClockInterface,
        repository: PairRepositoryInterface,
    ) -> None:
        self._clock = clock
        self._repository = repository

    async def execute(self, data: DissolvePairData) -> None:
        # Authorization is the lookup: only a live pair the requester belongs to comes back. Guard first.
        pair = await self._repository.find_active_by_person(data.requester_id)
        if pair is None:
            raise NotPairedError()

        # Real data dependency (dissolve needs the resolved pair) — await sequentially, no gather.
        now = await self._clock.now()
        pair.dissolve(now)
        await self._repository.dissolve(pair)
