from __future__ import annotations

from trocado.features.pairing.application.data.current_pair_data import CurrentPairData
from trocado.features.pairing.application.interfaces.pair_repository_interface import (
    PairRepositoryInterface,
)
from trocado.features.pairing.application.interfaces.person_directory_interface import (
    PersonDirectoryInterface,
)
from trocado.features.pairing.application.mappers.current_pair_data_mapper import (
    CurrentPairDataMapper,
)
from trocado.features.pairing.domain.virtual_objects.current_pair_virtual_object import (
    CurrentPairVirtualObject,
)


class GetCurrentPairUseCase:
    """Read the reader's current pair: "am I paired? with whom, since when?".

    The deliberate inversion of the couple *views* (`couple-budget` / `couple-expenses`, which raise
    `NotPairedError`): this is the *status* read, so being unpaired is a valid answer (`None`), never an
    error. When a live pair exists, the partner is resolved from the reader's side and named through the
    identity directory.
    """

    def __init__(
        self,
        pair_repository: PairRepositoryInterface,
        person_directory: PersonDirectoryInterface,
    ) -> None:
        self._pair_repository = pair_repository
        self._person_directory = person_directory

    async def execute(self, reader_id: str) -> CurrentPairData | None:
        pair = await self._pair_repository.find_active_by_person(reader_id)
        if pair is None:
            # Not paired is a valid answer for a status read — never NotPairedError.
            return None

        partner_id = pair.person_b_id if reader_id == pair.person_a_id else pair.person_a_id

        # Real data dependency on partner_id — await sequentially, never gather.
        profile = await self._person_directory.find_active_profile(partner_id)
        if profile is None:
            # A live pair guarantees an active partner (account deletion dissolves pairs), so an
            # unresolvable partner is a data-integrity breach, not the routine unpaired case.
            raise RuntimeError("Par ativo com parceiro não resolvido.")

        virtual_object = CurrentPairVirtualObject(
            pair=pair,
            reader_id=reader_id,
            partner_id=profile.id,
            partner_name=profile.name,
        )
        return CurrentPairDataMapper.to_data(virtual_object)
