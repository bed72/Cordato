class InvalidAmountError(Exception):
    """Raised when an expense amount is not greater than zero."""

    def __init__(self) -> None:
        super().__init__("Valor deve ser maior que zero.")
