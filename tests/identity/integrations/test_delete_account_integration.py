import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.budgeting.application.interfaces.budget_repository_interface import (
    BudgetRepositoryInterface,
)
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository
from trocado.features.expenses.application.interfaces.expense_repository_interface import (
    ExpenseRepositoryInterface,
)
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository
from trocado.features.identity.application.data.delete_account_data import DeleteAccountData
from trocado.features.identity.application.data.sign_up_data import SignUpData
from trocado.features.identity.application.interfaces.budget_eraser_interface import BudgetEraserInterface
from trocado.features.identity.application.interfaces.expense_eraser_interface import ExpenseEraserInterface
from trocado.features.identity.application.interfaces.pair_dissolver_interface import PairDissolverInterface
from trocado.features.identity.application.use_cases.delete_account_use_case import DeleteAccountUseCase
from trocado.features.identity.application.use_cases.sign_up_use_case import SignUpUseCase
from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject
from trocado.features.identity.infrastructure.gateways.password_hasher import PasswordHasher
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository
from trocado.features.pairing.domain.entities.pair_entity import PairEntity
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository


# Test-local bridges standing in for the composition-root adapters (deferred with the web/ORM): they wrap
# the real budget/expense/pair repositories behind identity's own ports.
class _BudgetEraserBridge(BudgetEraserInterface):
    def __init__(self, repository: BudgetRepositoryInterface) -> None:
        self._repository = repository

    async def erase_for_person(self, person_id: str) -> None:
        await self._repository.erase_for_person(person_id)


class _ExpenseEraserBridge(ExpenseEraserInterface):
    def __init__(self, repository: ExpenseRepositoryInterface) -> None:
        self._repository = repository

    async def erase_for_person(self, person_id: str) -> None:
        await self._repository.erase_for_person(person_id)


class _PairDissolverBridge(PairDissolverInterface):
    def __init__(self, repository: PairRepository, clock: ClockInterface) -> None:
        self._clock = clock
        self._repository = repository

    async def dissolve_for_person(self, person_id: str) -> None:
        pair = await self._repository.find_active_by_person(person_id)
        if pair is None:  # idempotent: deleting an account succeeds whether or not the person was paired
            return
        pair.dissolve(await self._clock.now())
        await self._repository.dissolve(pair)


_FIXED = datetime(2026, 6, 24, tzinfo=UTC)


def test_real_adapters_erase_the_ledger_free_the_email_and_dissolve_the_pair() -> None:
    person_repository = PersonRepository()
    budget_repository = BudgetRepository()
    expense_repository = ExpenseRepository()
    pair_repository = PairRepository()

    register = SignUpUseCase(
        clock=Clock(),
        repository=person_repository,
        hasher=PasswordHasher(),
        identifier=IdentifierProvider(),
    )
    created = asyncio.run(register.execute(SignUpData(name="Ana", email="ana@example.com", password="supersecret")))
    person_id = created.id

    # Seed a ledger and a live pair for the person.
    asyncio.run(
        budget_repository.create(
            BudgetEntity.create(
                id="budget-1",
                note=None,
                person_id=person_id,
                created_at=_FIXED,
                start_date=date(2026, 6, 1),
                end_date=date(2026, 6, 30),
                amount=MoneyValueObject(Decimal("500.00")),
            )
        )
    )
    asyncio.run(
        expense_repository.create(
            ExpenseEntity.create(
                id="exp-1",
                person_id=person_id,
                description="almoço",
                created_at=_FIXED,
                occurred_on=date(2026, 6, 20),
                amount=MoneyValueObject(Decimal("10.00")),
            )
        )
    )
    asyncio.run(
        pair_repository.create(
            PairEntity.create(id="pair-1", person_a_id=person_id, person_b_id="partner", created_at=_FIXED)
        )
    )

    delete = DeleteAccountUseCase(
        hasher=PasswordHasher(),
        repository=person_repository,
        budget_eraser=_BudgetEraserBridge(budget_repository),
        expense_eraser=_ExpenseEraserBridge(expense_repository),
        pair_dissolver=_PairDissolverBridge(pair_repository, Clock()),
    )

    asyncio.run(delete.execute(DeleteAccountData(requester_id=person_id, password=PasswordValueObject("supersecret"))))

    # The ledger is physically gone.
    assert budget_repository._budgets == {}
    assert expense_repository._expenses == {}
    # The account is retired and the former pair is no longer live.
    assert asyncio.run(person_repository.find_active_by_id(person_id)) is None
    assert asyncio.run(pair_repository.find_active_by_person(person_id)) is None
    assert asyncio.run(pair_repository.find_active_by_person("partner")) is None

    # The freed email is reusable by a brand-new person, with a new id and an empty ledger.
    reused = asyncio.run(register.execute(SignUpData(name="Bea", email="ana@example.com", password="anothersecret")))
    assert reused.id != person_id


def test_wrong_password_leaves_everything_intact() -> None:
    person_repository = PersonRepository()
    budget_repository = BudgetRepository()
    expense_repository = ExpenseRepository()
    pair_repository = PairRepository()

    register = SignUpUseCase(
        clock=Clock(),
        repository=person_repository,
        hasher=PasswordHasher(),
        identifier=IdentifierProvider(),
    )
    created = asyncio.run(register.execute(SignUpData(name="Ana", email="ana@example.com", password="supersecret")))
    asyncio.run(
        budget_repository.create(
            BudgetEntity.create(
                id="budget-1",
                note=None,
                person_id=created.id,
                created_at=_FIXED,
                start_date=date(2026, 6, 1),
                end_date=date(2026, 6, 30),
                amount=MoneyValueObject(Decimal("500.00")),
            )
        )
    )

    delete = DeleteAccountUseCase(
        hasher=PasswordHasher(),
        repository=person_repository,
        budget_eraser=_BudgetEraserBridge(budget_repository),
        expense_eraser=_ExpenseEraserBridge(expense_repository),
        pair_dissolver=_PairDissolverBridge(pair_repository, Clock()),
    )

    with pytest.raises(IncorrectPasswordError):
        asyncio.run(
            delete.execute(DeleteAccountData(requester_id=created.id, password=PasswordValueObject("wrongpassword")))
        )

    # Guard ran first: the budget survives and the account is still active.
    assert set(budget_repository._budgets) == {"budget-1"}
    assert asyncio.run(person_repository.find_active_by_id(created.id)) is not None
