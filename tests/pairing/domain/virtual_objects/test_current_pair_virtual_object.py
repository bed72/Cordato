from datetime import UTC, datetime

import pytest

from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.domain.virtual_objects.current_pair_virtual_object import (
    CurrentPairVirtualObject,
)

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _pair() -> PairEntity:
    return PairEntity.create(
        id="pair-1",
        person_b_id="bob",
        person_a_id="alice",
        created_at=_FIXED_NOW,
    )


def test_derived_properties_echo_the_pair() -> None:
    view = CurrentPairVirtualObject(
        pair=_pair(),
        partner_id="bob",
        reader_id="alice",
        partner_name="Bob",
    )

    assert view.pair_id == "pair-1"
    assert view.partner_id == "bob"
    assert view.partner_name == "Bob"
    assert view.paired_since == _FIXED_NOW


def test_reader_may_be_either_member() -> None:
    as_b = CurrentPairVirtualObject(
        pair=_pair(),
        reader_id="bob",
        partner_id="alice",
        partner_name="Alice",
    )

    assert as_b.partner_id == "alice"


def test_partner_equal_to_reader_is_rejected() -> None:
    with pytest.raises(ValueError):
        CurrentPairVirtualObject(
            pair=_pair(),
            reader_id="alice",
            partner_id="alice",
            partner_name="Alice",
        )


def test_partner_outside_the_pair_is_rejected() -> None:
    with pytest.raises(ValueError):
        CurrentPairVirtualObject(
            pair=_pair(),
            reader_id="alice",
            partner_id="carol",
            partner_name="Carol",
        )


def test_reader_outside_the_pair_is_rejected() -> None:
    with pytest.raises(ValueError):
        CurrentPairVirtualObject(
            pair=_pair(),
            partner_id="bob",
            reader_id="carol",
            partner_name="Bob",
        )
