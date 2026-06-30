from __future__ import annotations

from typing import Annotated

from litestar import Controller, delete, get, patch, post
from litestar.di import NamedDependency
from litestar.params import Parameter

from trocado.features.expenses.application.data.delete_expense_data import DeleteExpenseData
from trocado.features.expenses.application.use_cases.create_expense_use_case import CreateExpenseUseCase
from trocado.features.expenses.application.use_cases.delete_expense_use_case import DeleteExpenseUseCase
from trocado.features.expenses.application.use_cases.list_expenses_use_case import ListExpensesUseCase
from trocado.features.expenses.application.use_cases.update_expense_use_case import UpdateExpenseUseCase
from trocado.features.expenses.infrastructure.http.mappers.requests.create_expense_request_mapper import (
    CreateExpenseRequestMapper,
)
from trocado.features.expenses.infrastructure.http.mappers.requests.update_expense_request_mapper import (
    UpdateExpenseRequestMapper,
)
from trocado.features.expenses.infrastructure.http.mappers.responses.expense_response_mapper import (
    ExpenseResponseMapper,
)
from trocado.features.expenses.infrastructure.http.requests.create_expense_request import CreateExpenseRequest
from trocado.features.expenses.infrastructure.http.requests.update_expense_request import UpdateExpenseRequest
from trocado.features.expenses.infrastructure.http.responses.expense_response import ExpenseResponse
from trocado.features.identity.infrastructure.http.providers.current_person_provider import CurrentPersonProvider


class ExpenseController(Controller):
    """Driving adapter for expenses over HTTP — a Litestar-native class controller.

    Binds, maps, delegates, and frames — no business logic. The use cases are injected by name from the
    composition root's scoped dependencies; the framework-free, server-free testable unit stays the use
    case itself, exercised in ``application`` with fakes.
    """

    path = "/expenses"
    tags = ["Expenses"]

    @post(
        summary="Registrar despesa",
        description=(
            "Registra uma nova despesa individual para a pessoa atuante: um valor em BRL e uma data. "
            "A descrição é opcional. Responde **201 Created** com a despesa criada. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def create(
        self,
        data: CreateExpenseRequest,
        create_expense_use_case: NamedDependency[CreateExpenseUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> ExpenseResponse:
        """``POST /expenses`` — record a new expense, answering ``201 Created``."""
        person = await current_person_provider.data()
        command = CreateExpenseRequestMapper.to_data(request=data, person_id=person.id)
        expense = await create_expense_use_case.execute(command)
        return ExpenseResponseMapper.to_response(expense)

    @get(
        summary="Listar despesas",
        description=(
            "Retorna as despesas vivas da pessoa atuante, ordenadas por data mais recente primeiro. "
            "Lista vazia quando não há despesas. Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def list_expenses(
        self,
        list_expenses_use_case: NamedDependency[ListExpensesUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> list[ExpenseResponse]:
        """``GET /expenses`` — list the acting person's live expenses, most-recent-first."""
        person = await current_person_provider.data()
        expenses = await list_expenses_use_case.execute(person.id)
        return [ExpenseResponseMapper.to_response(e) for e in expenses]

    @patch(
        "/{expense_id:str}",
        summary="Editar despesa",
        description=(
            "Substitui todos os campos editáveis (valor, data, descrição) de uma despesa da pessoa atuante. "
            "Semântica de **substituição completa** — todos os campos são obrigatórios. "
            "Responde **200 OK** com a despesa atualizada. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def update(
        self,
        expense_id: Annotated[str, Parameter(title="expense_id")],
        data: UpdateExpenseRequest,
        update_expense_use_case: NamedDependency[UpdateExpenseUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> ExpenseResponse:
        """``PATCH /expenses/{expense_id}`` — full-replace a live expense, answering ``200 OK``."""
        person = await current_person_provider.data()
        command = UpdateExpenseRequestMapper.to_data(request=data, person_id=person.id, expense_id=expense_id)
        expense = await update_expense_use_case.execute(command)
        return ExpenseResponseMapper.to_response(expense)

    @delete(
        "/{expense_id:str}",
        summary="Remover despesa",
        description=(
            "Soft-deleta uma despesa da pessoa atuante. A despesa deixa de aparecer nas listagens normais "
            "mas permanece visível na auditoria. Responde **204 No Content** sem corpo. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def remove(
        self,
        expense_id: Annotated[str, Parameter(title="expense_id")],
        delete_expense_use_case: NamedDependency[DeleteExpenseUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> None:
        """``DELETE /expenses/{expense_id}`` — soft-delete a live expense, answering ``204 No Content``."""
        person = await current_person_provider.data()
        command = DeleteExpenseData(requester_id=person.id, expense_id=expense_id)
        await delete_expense_use_case.execute(command)
