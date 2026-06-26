class IncorrectPasswordError(Exception):
    """Raised when the password re-confirming a destructive action does not match the stored hash.

    The message names only the wrong factor — never the account or its data. Since the requester is
    acting on their *own* account, this is not account enumeration.
    """

    def __init__(self) -> None:
        super().__init__("Senha incorreta.")
