import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from tests.core.fakes.fake_clock import FakeClock
from tests.core.fakes.fake_identifier_provider import FakeIdentifierProvider
from tests.expenses.fakes.fake_expense_repository import FakeExpenseRepository
from trocado.core.domain.errors.invalid_money_error import InvalidMoneyError
from trocado.features.expenses.application.data.create_expense_data import CreateExpenseData
from trocado.features.expenses.application.use_cases.create_expense_use_case import (
    CreateExpenseUseCase,
)
from trocado.features.expenses.domain.errors.invalid_amount_error import InvalidAmountError

_A_DAY = date(2026, 6, 20)
_FIXED_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _build_use_case(
    repository: FakeExpenseRepository | None = None,
    identifier: str = "exp-1",
) -> tuple[CreateExpenseUseCase, FakeExpenseRepository]:
    repository = repository or FakeExpenseRepository()
    use_case = CreateExpenseUseCase(
        repository=repository,
        clock=FakeClock(_FIXED_NOW),
        identifier=FakeIdentifierProvider(identifier),
    )

    return use_case, repository


def _command(amount: str = "19.90", description: str | None = "almoço") -> CreateExpenseData:
    return CreateExpenseData(person_id="person-1", amount=Decimal(amount), occurred_on=_A_DAY, description=description)


def test_successful_recording_returns_public_data() -> None:
    use_case, repository = _build_use_case(identifier="new-id")

    data = asyncio.run(use_case.execute(_command()))

    assert data.id == "new-id"
    assert data.occurred_on == _A_DAY
    assert data.description == "almoço"
    assert data.person_id == "person-1"
    assert data.created_at == _FIXED_NOW
    assert len(repository.expenses) == 1
    assert data.amount == Decimal("19.90")


def test_recording_without_description() -> None:
    use_case, _ = _build_use_case()

    data = asyncio.run(use_case.execute(_command(description=None)))

    assert data.description is None


def test_returned_data_has_no_budget_reference() -> None:
    use_case, _ = _build_use_case()

    data = asyncio.run(use_case.execute(_command()))

    assert not hasattr(data, "budget")
    assert not hasattr(data, "budget_id")


@pytest.mark.parametrize("amount", ["0", "0.00", "-5.00"])
def test_non_positive_amount_is_rejected(amount: str) -> None:
    use_case, repository = _build_use_case()

    with pytest.raises(InvalidAmountError):
        asyncio.run(use_case.execute(_command(amount=amount)))
    assert repository.expenses == []


@pytest.mark.parametrize("amount", ["10.005", "0.001"])
def test_over_precise_amount_is_rejected(amount: str) -> None:
    use_case, repository = _build_use_case()

    with pytest.raises(InvalidMoneyError):
        asyncio.run(use_case.execute(_command(amount=amount)))
    assert repository.expenses == []


def test_non_finite_amount_is_rejected() -> None:
    use_case, repository = _build_use_case()

    with pytest.raises(InvalidMoneyError):
        asyncio.run(use_case.execute(_command(amount="NaN")))
    assert repository.expenses == []


def test_blank_description_becomes_absent() -> None:
    use_case, _ = _build_use_case()

    data = asyncio.run(use_case.execute(_command(description="   ")))

    assert data.description is None


def test_description_is_trimmed() -> None:
    use_case, _ = _build_use_case()

    data = asyncio.run(use_case.execute(_command(description="  almoço  ")))

    assert data.description == "almoço"


def test_id_and_created_at_come_from_ports() -> None:
    use_case, repository = _build_use_case(identifier="from-port")

    data = asyncio.run(use_case.execute(_command()))

    assert data.id == "from-port"
    assert data.created_at == _FIXED_NOW
    assert repository.expenses[0].id == "from-port"
