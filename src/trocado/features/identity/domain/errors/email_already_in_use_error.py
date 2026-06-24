class EmailAlreadyInUseError(Exception):
    """Raised when creating a person with an email already held by an active person.

    The message deliberately echoes no email — revealing which addresses exist enables account enumeration.
    """

    def __init__(self) -> None:
        super().__init__("E-mail já está em uso.")
