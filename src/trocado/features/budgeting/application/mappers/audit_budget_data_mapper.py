from __future__ import annotations

from trocado.features.budgeting.application.data.audit_budget_data import AuditBudgetData
from trocado.features.budgeting.domain.entities.budget_entity import BudgetEntity


class AuditBudgetDataMapper:
    """Maps a BudgetEntity to its audit read-model, unwrapping money to a plain Decimal and surfacing
    ``deleted_at`` (which the plain ``BudgetDataMapper`` deliberately drops)."""

    @staticmethod
    def to_data(budget: BudgetEntity) -> AuditBudgetData:
        return AuditBudgetData(
            id=budget.id,
            note=budget.note,
            end_date=budget.end_date,
            amount=budget.amount.value,
            person_id=budget.person_id,
            start_date=budget.start_date,
            created_at=budget.created_at,
            deleted_at=budget.deleted_at,
        )
