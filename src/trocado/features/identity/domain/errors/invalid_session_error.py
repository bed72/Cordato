class InvalidSessionError(Exception):
    """Raised when a session token does not resolve to a live session of an active person.

    One generic outcome for every failure mode — unknown token, expired session, revoked session, or a
    person no longer active — so it never reveals which condition failed. The message names no token and no
    person: leaking session state would be an oracle for guessing valid tokens.
    """

    def __init__(self) -> None:
        super().__init__("Sessão inválida.")
