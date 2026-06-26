import asyncio
from datetime import UTC, datetime

import pytest

from tests.identity.fakes.fake_budget_eraser import FakeBudgetEraser
from tests.identity.fakes.fake_expense_eraser import FakeExpenseEraser
from tests.identity.fakes.fake_pair_dissolver import FakePairDissolver
from tests.identity.fakes.fake_password_hasher import FakePasswordHasher
from tests.identity.fakes.fake_person_repository import FakePersonRepository
from trocado.features.identity.application.data.delete_account_data import DeleteAccountData
from trocado.features.identity.application.use_cases.delete_account_use_case import DeleteAccountUseCase
from trocado.features.identity.domain.entities.person_entity import PersonEntity
from trocado.features.identity.domain.enums.person_status import PersonStatus
from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError
from trocado.features.identity.domain.value_objects.email_value_object import EmailValueObject
from trocado.features.identity.domain.value_objects.name_value_object import NameValueObject
from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject

_PERSON_ID = "person-1"
_PASSWORD = "supersecret"
_NOW = datetime(2026, 6, 24, tzinfo=UTC)


def _person(person_id: str = _PERSON_ID, password: str = f"hashed::{_PASSWORD}") -> PersonEntity:
    # The fake hasher stores `hashed::<plaintext>` and verifies against it.
    return PersonEntity(
        id=person_id,
        status=PersonStatus.ACTIVE,
        password=password,
        created_at=_NOW,
        name=NameValueObject("Ana"),
        email=EmailValueObject("ana@example.com"),
    )


def _build(
    *people: PersonEntity,
) -> tuple[DeleteAccountUseCase, FakePersonRepository, FakeBudgetEraser, FakeExpenseEraser, FakePairDissolver]:
    budget_eraser = FakeBudgetEraser()
    expense_eraser = FakeExpenseEraser()
    pair_dissolver = FakePairDissolver()
    repository = FakePersonRepository(*people)
    use_case = DeleteAccountUseCase(
        hasher=FakePasswordHasher(),
        repository=repository,
        budget_eraser=budget_eraser,
        expense_eraser=expense_eraser,
        pair_dissolver=pair_dissolver,
    )
    return use_case, repository, budget_eraser, expense_eraser, pair_dissolver


def _delete(use_case: DeleteAccountUseCase, password: str = _PASSWORD) -> None:
    data = DeleteAccountData(requester_id=_PERSON_ID, password=PasswordValueObject(password))
    asyncio.run(use_case.execute(data))


def test_correct_password_erases_ledger_retires_account_and_dissolves_pair() -> None:
    person = _person()
    use_case, repository, budget_eraser, expense_eraser, pair_dissolver = _build(person)

    _delete(use_case)

    # Ledger cascade fired, scoped to the requester alone.
    assert budget_eraser.erased == [_PERSON_ID]
    assert expense_eraser.erased == [_PERSON_ID]
    # Account retired and persisted: no longer active, email neutralized.
    assert person.status is PersonStatus.DELETED
    # Pair dissolved as a consequence — unconditionally delegated (idempotency lives in the adapter).
    assert pair_dissolver.dissolved == [_PERSON_ID]
    assert person.email.value == f"deleted+{_PERSON_ID}@trocado.invalid"
    assert asyncio.run(repository.find_active_by_id(_PERSON_ID)) is None


def test_deletion_delegates_dissolve_unconditionally() -> None:
    # The use case never branches on pairing: it always asks the dissolver, which is a no-op when unpaired.
    use_case, _, _, _, pair_dissolver = _build(_person())

    _delete(use_case)

    assert pair_dissolver.dissolved == [_PERSON_ID]


def test_wrong_password_rejects_and_changes_nothing() -> None:
    person = _person()
    use_case, repository, budget_eraser, expense_eraser, pair_dissolver = _build(person)

    with pytest.raises(IncorrectPasswordError):
        _delete(use_case, password="wrongpassword")

    # Guard ran first: nothing erased, nothing dissolved, the account untouched and still active.
    assert budget_eraser.erased == []
    assert expense_eraser.erased == []
    assert pair_dissolver.dissolved == []
    assert person.status is PersonStatus.ACTIVE
    assert person.email == EmailValueObject("ana@example.com")
    assert asyncio.run(repository.find_active_by_id(_PERSON_ID)) is person


def test_unknown_or_non_active_requester_rejects_like_a_wrong_password() -> None:
    # No oracle: an unresolved requester fails identically to a bad password, before any work.
    use_case, _, budget_eraser, expense_eraser, pair_dissolver = _build()  # empty repository

    with pytest.raises(IncorrectPasswordError):
        _delete(use_case)

    assert budget_eraser.erased == []
    assert expense_eraser.erased == []
    assert pair_dissolver.dissolved == []
