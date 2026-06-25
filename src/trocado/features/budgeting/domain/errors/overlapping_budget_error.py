class OverlappingBudgetError(Exception):
    """Raised when a new budget's date range overlaps an existing live budget of the same person."""

    def __init__(self) -> None:
        super().__init__("Já existe um orçamento neste período.")
