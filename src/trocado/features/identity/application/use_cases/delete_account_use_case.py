from __future__ import annotations

import asyncio

from trocado.features.identity.application.data.delete_account_data import DeleteAccountData
from trocado.features.identity.application.interfaces.budget_eraser_interface import BudgetEraserInterface
from trocado.features.identity.application.interfaces.expense_eraser_interface import ExpenseEraserInterface
from trocado.features.identity.application.interfaces.pair_dissolver_interface import PairDissolverInterface
from trocado.features.identity.application.interfaces.password_hasher_interface import (
    PasswordHasherInterface,
)
from trocado.features.identity.application.interfaces.person_repository_interface import (
    PersonRepositoryInterface,
)
from trocado.features.identity.application.interfaces.session_repository_interface import (
    SessionRepositoryInterface,
)
from trocado.features.identity.domain.errors.incorrect_password_error import IncorrectPasswordError


class DeleteAccountUseCase:
    """Delete an account — the domain's only physical deletion, and a single guarded, irreversible operation.

    Identity is re-confirmed by the password *before* anything is touched; a mismatch (or an unresolved
    requester — the two read alike, no oracle) rejects with ``IncorrectPasswordError`` and changes nothing.
    Only past that guard does the cascade run: physically erase the person's budgets and expenses, purge all
    of the person's sessions, retire the account (neutralized email + ``DELETED`` status), and dissolve any
    live pair as a consequence (idempotent — a no-op when unpaired). Those five effects are mutually
    independent, so they are issued together. There is no read-model and no restore: the only outcome is
    absence.

    Atomicity is the contract; at the in-memory stage there is no transaction manager, so the guard runs
    strictly first (the only pre-mutation failure leaves everything intact) and the indivisible boundary
    arrives with the ORM, behind these same ports.
    """

    def __init__(
        self,
        hasher: PasswordHasherInterface,
        budget_eraser: BudgetEraserInterface,
        expense_eraser: ExpenseEraserInterface,
        pair_dissolver: PairDissolverInterface,
        person_repository: PersonRepositoryInterface,
        session_repository: SessionRepositoryInterface,
    ) -> None:
        self._hasher = hasher
        self._budget_eraser = budget_eraser
        self._expense_eraser = expense_eraser
        self._pair_dissolver = pair_dissolver
        self._person_repository = person_repository
        self._session_repository = session_repository

    async def execute(self, data: DeleteAccountData) -> None:
        # Guard first: re-confirm identity before any destructive work. An unknown/non-active id and a
        # wrong password fail identically — no oracle reveals which.
        person = await self._person_repository.find_active_by_id(data.requester_id)
        if person is None or not await self._hasher.verify(data.password, person.password):
            raise IncorrectPasswordError()

        person.delete()

        # Past the guard, the five effects are mutually independent — issue them together.
        await asyncio.gather(
            self._budget_eraser.erase_for_person(person.id),
            self._expense_eraser.erase_for_person(person.id),
            self._pair_dissolver.dissolve_for_person(person.id),
            self._session_repository.purge_for_person(person.id),
            self._person_repository.delete(person),
        )
