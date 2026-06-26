class BudgetNotFoundError(Exception):
    """Raised when the requester owns no live budget with the given id.

    Deliberately indistinguishable across unknown id, foreign owner, and already-deleted budget — the
    message never reveals whether another person's budget exists.
    """

    def __init__(self) -> None:
        super().__init__("Orçamento não encontrado.")
