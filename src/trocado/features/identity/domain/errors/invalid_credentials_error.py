class InvalidCredentialsError(Exception):
    """Raised when a sign-in fails, for any reason. The single, generic outcome of a bad credential.

    Sign-in is *pre-authentication*: the requester has not yet proven who they are, so the error must name
    neither factor. A malformed email, an email belonging to no active person, and a wrong password all
    raise this same error with this same message — revealing which half failed would be account
    enumeration. Distinct from `IncorrectPasswordError`, which guards a destructive action on an *already
    known* account and may therefore be specific.
    """

    def __init__(self) -> None:
        super().__init__("E-mail ou senha inválidos.")
