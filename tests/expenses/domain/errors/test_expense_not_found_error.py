from trocado.features.expenses.domain.errors.expense_not_found_error import ExpenseNotFoundError


def test_carries_a_pt_br_non_leaking_message() -> None:
    error = ExpenseNotFoundError()

    # Generic by design: never echoes an id or owner — it must not reveal whether someone else's expense exists.
    assert str(error) == "Despesa não encontrada."


def test_is_an_exception() -> None:
    assert isinstance(ExpenseNotFoundError(), Exception)
