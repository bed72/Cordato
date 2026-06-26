import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

from tests.pairing.fakes.fake_partner_expense_reader import FakePartnerExpenseReader
from trocado.features.pairing.application.data.partner_expense_data import PartnerExpenseData
from trocado.features.pairing.application.use_cases.get_couple_expenses_use_case import (
    GetCoupleExpensesUseCase,
)
from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository

_FIXED_NOW = datetime(2026, 6, 24, 12, tzinfo=UTC)


def test_real_pair_repository_drives_the_couple_view() -> None:
    pair_repository = PairRepository()
    asyncio.run(
        pair_repository.create(
            PairEntity.create(
                id="pair-1",
                created_at=_FIXED_NOW,
                person_a_id="alice",
                person_b_id="bob",
            )
        )
    )

    reader = FakePartnerExpenseReader(
        {
            "alice": [
                PartnerExpenseData(
                    id="a1",
                    person_id="alice",
                    amount=Decimal("30.00"),
                    occurred_on=date(2026, 6, 20),
                    created_at=_FIXED_NOW,
                    description="café",
                )
            ],
            "bob": [
                PartnerExpenseData(
                    id="b1",
                    person_id="bob",
                    amount=Decimal("12.50"),
                    occurred_on=date(2026, 6, 22),
                    created_at=_FIXED_NOW,
                    description=None,
                )
            ],
        }
    )

    use_case = GetCoupleExpensesUseCase(repository=pair_repository, partner_expense_reader=reader)

    # Read from Bob's point of view: his own spend is "mine", Alice's is "theirs", newest first.
    result = asyncio.run(use_case.execute("bob"))

    assert [(item.id, item.perspective) for item in result] == [("b1", "mine"), ("a1", "theirs")]
    assert result[1].amount == Decimal("30.00")
