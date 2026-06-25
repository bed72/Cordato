class InvalidBudgetAmountError(Exception):
    """Raised when a budget amount is not greater than zero."""

    def __init__(self) -> None:
        super().__init__("Valor do orçamento deve ser maior que zero.")
