from __future__ import annotations

from trocado.features.pairing.application.data.current_pair_data import CurrentPairData
from trocado.features.pairing.domain.virtual_objects.current_pair_virtual_object import (
    CurrentPairVirtualObject,
)


class CurrentPairDataMapper:
    """Maps a CurrentPairVirtualObject to its public read-model.

    Reads the Virtual Object's derived properties, leaving the reader-relative partner resolution in the
    domain.
    """

    @staticmethod
    def to_data(virtual_object: CurrentPairVirtualObject) -> CurrentPairData:
        return CurrentPairData(
            pair_id=virtual_object.pair_id,
            partner_id=virtual_object.partner_id,
            paired_since=virtual_object.paired_since,
            partner_name=virtual_object.partner_name,
        )
