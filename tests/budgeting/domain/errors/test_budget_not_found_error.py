from trocado.features.budgeting.domain.errors.budget_not_found_error import BudgetNotFoundError


def test_carries_a_pt_br_non_leaking_message() -> None:
    error = BudgetNotFoundError()

    # Generic by design: never echoes an id or owner — it must not reveal whether someone else's budget exists.
    assert str(error) == "Orçamento não encontrado."


def test_is_an_exception() -> None:
    assert isinstance(BudgetNotFoundError(), Exception)
