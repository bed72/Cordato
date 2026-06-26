class NotPairedError(Exception):
    """Raised when the reader is in no live pair — there is no couple to look through."""

    def __init__(self) -> None:
        super().__init__("Você não está em um par ativo.")
