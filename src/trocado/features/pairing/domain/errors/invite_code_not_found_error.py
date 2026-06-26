class InviteCodeNotFoundError(Exception):
    """Raised when an accepted token matches no invite. Stays silent on whether a token exists."""

    def __init__(self) -> None:
        super().__init__("Convite inválido.")
