from __future__ import annotations

from litestar import Router
from litestar.di import NamedDependency, Provide

from trocado.core.application.interfaces.clock_interface import ClockInterface
from trocado.core.application.interfaces.identifier_provider_interface import IdentifierProviderInterface
from trocado.core.infrastructure.http.errors.handlers.exception_handlers import build_domain_exception_handlers
from trocado.features.pairing.application.interfaces.invite_code_repository_interface import (
    InviteCodeRepositoryInterface,
)
from trocado.features.pairing.application.interfaces.pair_repository_interface import PairRepositoryInterface
from trocado.features.pairing.application.interfaces.partner_budget_reader_interface import (
    PartnerBudgetReaderInterface,
)
from trocado.features.pairing.application.interfaces.partner_expense_reader_interface import (
    PartnerExpenseReaderInterface,
)
from trocado.features.pairing.application.interfaces.person_directory_interface import PersonDirectoryInterface
from trocado.features.pairing.application.interfaces.token_generator_interface import TokenGeneratorInterface
from trocado.features.pairing.application.use_cases.accept_invite_code_use_case import AcceptInviteCodeUseCase
from trocado.features.pairing.application.use_cases.create_invite_code_use_case import CreateInviteCodeUseCase
from trocado.features.pairing.application.use_cases.dissolve_pair_use_case import DissolvePairUseCase
from trocado.features.pairing.application.use_cases.get_couple_budget_use_case import GetCoupleBudgetUseCase
from trocado.features.pairing.application.use_cases.get_couple_expenses_use_case import GetCoupleExpensesUseCase
from trocado.features.pairing.application.use_cases.get_current_pair_use_case import GetCurrentPairUseCase
from trocado.features.pairing.application.use_cases.revoke_invite_code_use_case import RevokeInviteCodeUseCase
from trocado.features.pairing.infrastructure.gateways.token_generator import TokenGenerator
from trocado.features.pairing.infrastructure.http.controllers.invite_controller import InviteController
from trocado.features.pairing.infrastructure.http.controllers.pair_controller import PairController
from trocado.features.pairing.infrastructure.http.errors.lookups.pairing_status_error import PAIRING_STATUS_ERROR
from trocado.features.pairing.infrastructure.repositories.invite_code_repository import InviteCodeRepository
from trocado.features.pairing.infrastructure.repositories.pair_repository import PairRepository


def register_pairing_router(
    person_directory: PersonDirectoryInterface,
    partner_budget_reader: PartnerBudgetReaderInterface,
    partner_expense_reader: PartnerExpenseReaderInterface,
) -> Router:
    """Build pairing's web slice: its controllers plus the dependencies **scoped to this feature**.

    The three cross-module adapters (`person_directory`, `partner_budget_reader`, `partner_expense_reader`)
    are built by the composition root — the only layer that may import from two feature packages
    simultaneously — and injected here. The pairing-owned ports (`pair_repository`, `invite_code_repository`,
    `token_generator`) are singletons built here. Use cases are per-request.

    Error framing is scoped to this router: pairing's domain errors are framed here; cross-cutting
    handlers (422, HTTP fallback) stay at the app layer.
    """
    token_generator = TokenGenerator()
    pair_repository = PairRepository()
    invite_code_repository = InviteCodeRepository()

    async def provide_pair_repository() -> PairRepositoryInterface:
        return pair_repository

    async def provide_invite_code_repository() -> InviteCodeRepositoryInterface:
        return invite_code_repository

    async def provide_token_generator() -> TokenGeneratorInterface:
        return token_generator

    async def provide_person_directory() -> PersonDirectoryInterface:
        return person_directory

    async def provide_partner_budget_reader() -> PartnerBudgetReaderInterface:
        return partner_budget_reader

    async def provide_partner_expense_reader() -> PartnerExpenseReaderInterface:
        return partner_expense_reader

    async def provide_create_invite_code_use_case(
        clock: NamedDependency[ClockInterface],
        identifier: NamedDependency[IdentifierProviderInterface],
        token_generator: NamedDependency[TokenGeneratorInterface],
        invite_code_repository: NamedDependency[InviteCodeRepositoryInterface],
    ) -> CreateInviteCodeUseCase:
        return CreateInviteCodeUseCase(
            clock=clock,
            identifier=identifier,
            token_generator=token_generator,
            repository=invite_code_repository,
        )

    async def provide_revoke_invite_code_use_case(
        clock: NamedDependency[ClockInterface],
        invite_code_repository: NamedDependency[InviteCodeRepositoryInterface],
    ) -> RevokeInviteCodeUseCase:
        return RevokeInviteCodeUseCase(clock=clock, repository=invite_code_repository)

    async def provide_accept_invite_code_use_case(
        clock: NamedDependency[ClockInterface],
        identifier: NamedDependency[IdentifierProviderInterface],
        pair_repository: NamedDependency[PairRepositoryInterface],
        person_directory: NamedDependency[PersonDirectoryInterface],
        invite_code_repository: NamedDependency[InviteCodeRepositoryInterface],
    ) -> AcceptInviteCodeUseCase:
        return AcceptInviteCodeUseCase(
            clock=clock,
            identifier=identifier,
            pair_repository=pair_repository,
            person_directory=person_directory,
            invite_repository=invite_code_repository,
        )

    async def provide_get_current_pair_use_case(
        pair_repository: NamedDependency[PairRepositoryInterface],
        person_directory: NamedDependency[PersonDirectoryInterface],
    ) -> GetCurrentPairUseCase:
        return GetCurrentPairUseCase(pair_repository=pair_repository, person_directory=person_directory)

    async def provide_dissolve_pair_use_case(
        clock: NamedDependency[ClockInterface],
        pair_repository: NamedDependency[PairRepositoryInterface],
    ) -> DissolvePairUseCase:
        return DissolvePairUseCase(clock=clock, repository=pair_repository)

    async def provide_get_couple_budget_use_case(
        pair_repository: NamedDependency[PairRepositoryInterface],
        partner_budget_reader: NamedDependency[PartnerBudgetReaderInterface],
    ) -> GetCoupleBudgetUseCase:
        return GetCoupleBudgetUseCase(repository=pair_repository, partner_budget_reader=partner_budget_reader)

    async def provide_get_couple_expenses_use_case(
        pair_repository: NamedDependency[PairRepositoryInterface],
        partner_expense_reader: NamedDependency[PartnerExpenseReaderInterface],
    ) -> GetCoupleExpensesUseCase:
        return GetCoupleExpensesUseCase(repository=pair_repository, partner_expense_reader=partner_expense_reader)

    return Router(
        path="/",
        route_handlers=[InviteController, PairController],
        dependencies={
            "pair_repository": Provide(provide_pair_repository),
            "token_generator": Provide(provide_token_generator),
            "person_directory": Provide(provide_person_directory),
            "partner_budget_reader": Provide(provide_partner_budget_reader),
            "partner_expense_reader": Provide(provide_partner_expense_reader),
            "dissolve_pair_use_case": Provide(provide_dissolve_pair_use_case),
            "invite_code_repository": Provide(provide_invite_code_repository),
            "get_current_pair_use_case": Provide(provide_get_current_pair_use_case),
            "get_couple_budget_use_case": Provide(provide_get_couple_budget_use_case),
            "create_invite_code_use_case": Provide(provide_create_invite_code_use_case),
            "revoke_invite_code_use_case": Provide(provide_revoke_invite_code_use_case),
            "accept_invite_code_use_case": Provide(provide_accept_invite_code_use_case),
            "get_couple_expenses_use_case": Provide(provide_get_couple_expenses_use_case),
        },
        exception_handlers=build_domain_exception_handlers(PAIRING_STATUS_ERROR),
    )
