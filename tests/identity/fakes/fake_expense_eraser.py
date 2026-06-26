from trocado.features.identity.application.interfaces.expense_eraser_interface import ExpenseEraserInterface


class FakeExpenseEraser(ExpenseEraserInterface):
    """Records which people were erased, so a use-case test can assert the cascade fired (and its scope)."""

    def __init__(self) -> None:
        self.erased: list[str] = []

    async def erase_for_person(self, person_id: str) -> None:
        self.erased.append(person_id)
