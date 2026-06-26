import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.pairing.fakes.fake_partner_budget_reader import FakePartnerBudgetReader
from trocado.features.pairing.application.data.partner_active_budget_data import (
    PartnerActiveBudgetData,
)
from trocado.features.pairing.application.use_cases.get_couple_budget_use_case import (
    GetCoupleBudgetUseCase,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository

_DAY = date(2026, 6, 24)
_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def _alice_budget() -> PartnerActiveBudgetData:
    return PartnerActiveBudgetData(
        person_id="alice",
        amount=Decimal("100.00"),
        end_date=date(2026, 6, 20),
        start_date=date(2026, 6, 1),
        total_spent=Decimal("40.00"),
    )


def _bob_budget() -> PartnerActiveBudgetData:
    return PartnerActiveBudgetData(
        person_id="bob",
        amount=Decimal("50.00"),
        end_date=date(2026, 6, 30),
        start_date=date(2026, 6, 10),
        total_spent=Decimal("35.00"),
    )


def test_real_pair_repository_drives_the_couple_budget() -> None:
    pair_repository = PairRepository()
    asyncio.run(
        pair_repository.create(
            PairEntity.create(
                id="pair-1",
                person_b_id="bob",
                person_a_id="alice",
                created_at=_FIXED_NOW,
            )
        )
    )

    # Both partners have an active budget → the panorama spans both and sums the money.
    both = FakePartnerBudgetReader({"alice": _alice_budget(), "bob": _bob_budget()})
    use_case = GetCoupleBudgetUseCase(repository=pair_repository, partner_budget_reader=both)

    combined = asyncio.run(use_case.execute("bob", _DAY))

    assert combined is not None
    assert combined.amount == Decimal("150.00")
    assert combined.remaining == Decimal("75.00")
    assert (combined.period_start, combined.period_end) == (date(2026, 6, 1), date(2026, 6, 30))

    # Only Alice has a budget → the panorama equals hers alone.
    only_alice = FakePartnerBudgetReader({"alice": _alice_budget()})
    use_case = GetCoupleBudgetUseCase(repository=pair_repository, partner_budget_reader=only_alice)

    single = asyncio.run(use_case.execute("bob", _DAY))
    assert single is not None
    assert single.amount == Decimal("100.00")
    assert (single.period_start, single.period_end) == (date(2026, 6, 1), date(2026, 6, 20))

    # Neither has a budget → there is no panorama.
    none = FakePartnerBudgetReader({})
    use_case = GetCoupleBudgetUseCase(repository=pair_repository, partner_budget_reader=none)

    assert asyncio.run(use_case.execute("bob", _DAY)) is None
