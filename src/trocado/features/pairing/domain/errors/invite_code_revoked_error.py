class InviteCodeRevokedError(Exception):
    """Raised when an accepted code was killed by its creator — a revoked code is not redeemable."""

    def __init__(self) -> None:
        super().__init__("Convite inválido.")
