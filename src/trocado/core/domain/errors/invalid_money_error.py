class InvalidMoneyError(Exception):
    """Raised when a monetary amount is not a finite decimal or exceeds centavo precision."""

    def __init__(self) -> None:
        super().__init__("Valor monetário inválido.")
