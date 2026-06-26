class PersonNotActiveError(Exception):
    """Raised when the creator or the accepter is not an active person.

    Deliberately silent on *which* party is inactive, and never echoes an id — revealing it would be an
    account-status enumeration oracle.
    """

    def __init__(self) -> None:
        super().__init__("Conta indisponível.")
