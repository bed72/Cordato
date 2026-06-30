from __future__ import annotations

import asyncio

from litestar import Controller, delete, get
from litestar.di import NamedDependency

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.features.identity.infrastructure.http.providers.current_person_provider import CurrentPersonProvider
from trocado.features.pairing.application.data.dissolve_pair_data import DissolvePairData
from trocado.features.pairing.application.use_cases.dissolve_pair_use_case import DissolvePairUseCase
from trocado.features.pairing.application.use_cases.get_couple_budget_use_case import GetCoupleBudgetUseCase
from trocado.features.pairing.application.use_cases.get_couple_expenses_use_case import GetCoupleExpensesUseCase
from trocado.features.pairing.application.use_cases.get_current_pair_use_case import GetCurrentPairUseCase
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError
from trocado.features.pairing.infrastructure.http.mappers.responses.couple_budget_response_mapper import (
    CoupleBudgetResponseMapper,
)
from trocado.features.pairing.infrastructure.http.mappers.responses.couple_expense_response_mapper import (
    CoupleExpenseResponseMapper,
)
from trocado.features.pairing.infrastructure.http.mappers.responses.pair_response_mapper import PairResponseMapper
from trocado.features.pairing.infrastructure.http.responses.couple_budget_response import CoupleBudgetResponse
from trocado.features.pairing.infrastructure.http.responses.couple_expense_response import CoupleExpenseResponse
from trocado.features.pairing.infrastructure.http.responses.pair_response import PairResponse


class PairController(Controller):
    path = "/pair"
    tags = ["Pairing"]

    @get(
        summary="Par atual",
        description=(
            "Retorna o par vivo da pessoa atuante com o perfil do parceiro resolvido. "
            "Responde **404** quando não está em nenhum par vivo. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def current(
        self,
        current_person_provider: NamedDependency[CurrentPersonProvider],
        get_current_pair_use_case: NamedDependency[GetCurrentPairUseCase],
    ) -> PairResponse:
        """``GET /pair`` — current live pair with partner resolved; ``404`` when unpaired."""
        person = await current_person_provider.data()
        data = await get_current_pair_use_case.execute(person.id)
        if data is None:
            raise NotPairedError()
        return PairResponseMapper.to_response(data)

    @delete(
        summary="Dissolver par",
        description=(
            "Soft-deleta o par vivo da pessoa atuante. Ambos os parceiros mantêm seus dados intactos. "
            "Responde **404** quando não está em nenhum par vivo. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
        status_code=204,
    )
    async def dissolve(
        self,
        dissolve_pair_use_case: NamedDependency[DissolvePairUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> None:
        """``DELETE /pair`` — soft-dissolve the acting person's live pair, answering ``204 No Content``."""
        person = await current_person_provider.data()
        await dissolve_pair_use_case.execute(DissolvePairData(requester_id=person.id))

    @get(
        "/budget",
        summary="Orçamento do casal",
        description=(
            "Retorna o panorama combinado dos orçamentos ativos dos dois parceiros para hoje. "
            "Responde **200 OK** com ``null`` quando nenhum parceiro tem orçamento ativo hoje. "
            "Responde **404** quando não está em nenhum par vivo. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def couple_budget(
        self,
        clock: NamedDependency[ClockInterface],
        current_person_provider: NamedDependency[CurrentPersonProvider],
        get_couple_budget_use_case: NamedDependency[GetCoupleBudgetUseCase],
    ) -> CoupleBudgetResponse | None:
        """``GET /pair/budget`` — combined couple budget for today; ``null`` when none active; ``404`` when unpaired."""
        today, person = await asyncio.gather(clock.now(), current_person_provider.data())
        data = await get_couple_budget_use_case.execute(reader_id=person.id, day=today.date())
        if data is None:
            return None
        return CoupleBudgetResponseMapper.to_response(data)

    @get(
        "/expenses",
        summary="Despesas do casal",
        description=(
            "Retorna a união das despesas vivas dos dois parceiros, marcada com perspectiva ``mine``/``theirs``, "
            "ordenada por ``occurred_on`` descendente. Lista vazia é uma resposta válida. "
            "Responde **404** quando não está em nenhum par vivo. "
            "Requer autenticação via ``Authorization: Bearer <token>``."
        ),
    )
    async def couple_expenses(
        self,
        get_couple_expenses_use_case: NamedDependency[GetCoupleExpensesUseCase],
        current_person_provider: NamedDependency[CurrentPersonProvider],
    ) -> list[CoupleExpenseResponse]:
        """``GET /pair/expenses`` — union of both partners' live expenses; ``404`` when unpaired."""
        person = await current_person_provider.data()
        expenses = await get_couple_expenses_use_case.execute(reader_id=person.id)
        return [CoupleExpenseResponseMapper.to_response(expense) for expense in expenses]
