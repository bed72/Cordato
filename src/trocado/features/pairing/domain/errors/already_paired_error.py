class AlreadyPairedError(Exception):
    """Raised when the creator or the accepter is already in a live pair.

    Deliberately silent on *which* party is paired — revealing it would be a couple-membership oracle.
    """

    def __init__(self) -> None:
        super().__init__("Já existe um par ativo.")
