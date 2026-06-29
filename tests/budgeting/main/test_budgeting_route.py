from litestar import Router

from trocado.features.budgeting.main.budgeting_route import register_budgeting_router


def test_budgeting_is_a_router_carrying_its_own_scoped_dependencies() -> None:
    """The feature contributes a Router whose dependencies are scoped to it, not the app-wide namespace."""
    router = register_budgeting_router()

    assert isinstance(router, Router)
    assert set(router.dependencies) == {"budget_repository", "create_budget_use_case"}


def test_each_build_produces_a_fresh_router() -> None:
    """A new router (with its own singletons) per call — so a test can assemble an isolated app."""
    assert register_budgeting_router() is not register_budgeting_router()
