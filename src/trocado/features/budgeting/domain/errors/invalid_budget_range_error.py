class InvalidBudgetRangeError(Exception):
    """Raised when a budget's start date falls after its end date."""

    def __init__(self) -> None:
        super().__init__("Data inicial não pode ser posterior à data final.")
