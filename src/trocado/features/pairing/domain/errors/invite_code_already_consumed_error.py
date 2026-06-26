class InviteCodeAlreadyConsumedError(Exception):
    """Raised when an accepted code was already redeemed — single-use is final."""

    def __init__(self) -> None:
        super().__init__("Convite já utilizado.")
