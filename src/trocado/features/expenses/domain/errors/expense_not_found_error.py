class ExpenseNotFoundError(Exception):
    """Raised when the requester owns no live expense with the given id.

    Deliberately indistinguishable across unknown id, foreign owner, and already-deleted expense — the
    message never reveals whether another person's expense exists.
    """

    def __init__(self) -> None:
        super().__init__("Despesa não encontrada.")
