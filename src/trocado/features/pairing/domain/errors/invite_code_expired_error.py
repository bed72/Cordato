class InviteCodeExpiredError(Exception):
    """Raised when an accepted code is past its expiry window."""

    def __init__(self) -> None:
        super().__init__("Convite expirado.")
