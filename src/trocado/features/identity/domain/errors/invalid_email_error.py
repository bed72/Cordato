class InvalidEmailError(Exception):
    """Raised when an email is not a well-formed address. Message echoes no value (no enumeration)."""

    def __init__(self) -> None:
        super().__init__("E-mail inválido.")
