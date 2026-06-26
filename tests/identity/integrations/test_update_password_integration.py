import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from trocado.core.domain.value_objects.money_value_object import MoneyValueObject
from trocado.core.infrastructure.gateways.clock import Clock
from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity
from trocado.features.budgeting.infrastructure.repositories.budget_repository import BudgetRepository
from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity
from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository
from trocado.features.identity.application.data.session_data import SessionData
from trocado.features.identity.application.data.sign_in_data import SignInData
from trocado.features.identity.application.data.sign_up_data import SignUpData
from trocado.features.identity.application.data.update_password_data import UpdatePasswordData
from trocado.features.identity.application.use_cases.sign_in_use_case import SignInUseCase
from trocado.features.identity.application.use_cases.sign_up_use_case import SignUpUseCase
from trocado.features.identity.application.use_cases.update_password_use_case import UpdatePasswordUseCase
from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError
from trocado.features.identity.domain.errors.invalid_credentials_error import InvalidCredentialsError
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject
from trocado.features.identity.infrastructure.gateways.password_hasher import PasswordHasher
from trocado.features.identity.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.identity.infrastructure.repositories.person_repository import PersonRepository
from trocado.features.identity.infrastructure.repositories.session_repository import SessionRepository

_OLD = "supersecret"
_NEW = "brandnewpass"
_FIXED = datetime(2026, 6, 24, tzinfo=UTC)


def _sign_in(use_case: SignInUseCase, password: str = _OLD) -> SessionData:
    return asyncio.run(use_case.execute(SignInData(email="ana@example.com", password=password)))


def test_real_adapters_rotate_the_hash_purge_other_sessions_and_keep_the_acting_one() -> None:
    person_repository = PersonRepository()
    budget_repository = BudgetRepository()
    session_repository = SessionRepository()
    expense_repository = ExpenseRepository()

    register = SignUpUseCase(
        clock=Clock(),
        hasher=PasswordHasher(),
        repository=person_repository,
        identifier=IdentifierProvider(),
    )
    created = asyncio.run(register.execute(SignUpData(name="Ana", email="ana@example.com", password=_OLD)))
    person_id = created.id

    sign_in = SignInUseCase(
        clock=Clock(),
        hasher=PasswordHasher(),
        identifier=IdentifierProvider(),
        token_generator=TokenGenerator(),
        person_repository=person_repository,
        session_repository=session_repository,
    )
    # Two real, live sessions: the second is the acting one (the device the change is made from).
    stale = _sign_in(sign_in)
    acting = _sign_in(sign_in)

    # Seed a ledger to prove a password change never touches it.
    asyncio.run(
        budget_repository.create(
            BudgetEntity.create(
                note=None,
                id="budget-1",
                created_at=_FIXED,
                person_id=person_id,
                end_date=date(2026, 6, 30),
                start_date=date(2026, 6, 1),
                amount=MoneyValueObject(Decimal("500.00")),
            )
        )
    )
    asyncio.run(
        expense_repository.create(
            ExpenseEntity.create(
                id="exp-1",
                created_at=_FIXED,
                person_id=person_id,
                description="almoço",
                occurred_on=date(2026, 6, 20),
                amount=MoneyValueObject(Decimal("10.00")),
            )
        )
    )

    change = UpdatePasswordUseCase(
        hasher=PasswordHasher(),
        person_repository=person_repository,
        session_repository=session_repository,
    )
    asyncio.run(
        change.execute(
            UpdatePasswordData(
                requester_id=person_id,
                current_session_token=acting.token,
                new_password=PasswordValueObject(_NEW),
                current_password=PasswordValueObject(_OLD),
            )
        )
    )

    # The new password authenticates; the old one no longer does.
    assert _sign_in(sign_in, password=_NEW) is not None
    with pytest.raises(InvalidCredentialsError):
        _sign_in(sign_in, password=_OLD)

    # The acting session still resolves; the stale (pre-rotation) one was purged.
    assert asyncio.run(session_repository.find_valid_by_token(stale.token, _FIXED)) is None
    assert asyncio.run(session_repository.find_valid_by_token(acting.token, _FIXED)) is not None

    # The ledger is untouched.
    assert set(expense_repository._expenses) == {"exp-1"}
    assert set(budget_repository._budgets) == {"budget-1"}


def test_wrong_current_password_leaves_the_hash_and_sessions_intact() -> None:
    person_repository = PersonRepository()
    session_repository = SessionRepository()

    register = SignUpUseCase(
        clock=Clock(),
        hasher=PasswordHasher(),
        repository=person_repository,
        identifier=IdentifierProvider(),
    )
    created = asyncio.run(register.execute(SignUpData(name="Ana", email="ana@example.com", password=_OLD)))

    sign_in = SignInUseCase(
        clock=Clock(),
        hasher=PasswordHasher(),
        identifier=IdentifierProvider(),
        token_generator=TokenGenerator(),
        person_repository=person_repository,
        session_repository=session_repository,
    )
    acting = _sign_in(sign_in)

    change = UpdatePasswordUseCase(
        hasher=PasswordHasher(),
        person_repository=person_repository,
        session_repository=session_repository,
    )
    with pytest.raises(IncorrectPasswordError):
        asyncio.run(
            change.execute(
                UpdatePasswordData(
                    requester_id=created.id,
                    current_session_token=acting.token,
                    new_password=PasswordValueObject(_NEW),
                    current_password=PasswordValueObject("wrongpassword"),
                )
            )
        )

    # The guard ran first: the old password still authenticates and the acting session still resolves.
    assert _sign_in(sign_in, password=_OLD) is not None
    assert asyncio.run(session_repository.find_valid_by_token(acting.token, _FIXED)) is not None
