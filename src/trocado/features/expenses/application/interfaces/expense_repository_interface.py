from abc import ABC, abstractmethod

from trocado.features.expenses.domain.entities.expense_entity import ExpenseEntity


class ExpenseRepositoryInterface(ABC):
    """Port for persisting expenses.

    Recording an expense needs only ``create``. Reads — including the date-range query that will
    *derive* expense→budget belonging with no foreign key — arrive with the change that first reads
    expenses, where they can be specified against real query scenarios. Soft-deleted rows excluded from
    normal reads will be that adapter's responsibility.
    """

    @abstractmethod
    async def create(self, expense: ExpenseEntity) -> None:
        """Persist a new expense."""
        raise NotImplementedError
