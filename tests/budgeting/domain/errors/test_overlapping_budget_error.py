from trocado.features.budgeting.domain.errors.overlapping_budget_error import OverlappingBudgetError


def test_carries_ptbr_message() -> None:
    assert str(OverlappingBudgetError()) == "Já existe um orçamento neste período."
