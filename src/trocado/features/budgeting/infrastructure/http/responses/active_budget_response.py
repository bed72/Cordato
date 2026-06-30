from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class ActiveBudgetResponse(BaseModel):
    """Response body for the active-budget endpoint — the budget enriched with derived spend totals.

    Extends the plain budget read with ``total_spent`` (sum of the person's expenses within the budget
    period) and ``remaining`` (budget amount minus total_spent). Both are derived at read-time, never
    stored. Uses a separate DTO from ``BudgetResponse`` because the extra fields change the shape contract.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c162",
                    "person_id": "019f0f8a-1b2c-77bd-9a94-e7d47f72c000",
                    "amount": "500.00",
                    "start_date": "2026-06-01",
                    "end_date": "2026-06-30",
                    "note": "Orçamento de Julho",
                    "total_spent": "120.00",
                    "remaining": "380.00",
                    "created_at": "2026-06-28T18:43:18.207963Z",
                }
            ]
        }
    )

    id: str = Field(
        description="Identificador opaco do orçamento (uuid7, time-ordered).",
        examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c162"],
    )
    person_id: str = Field(
        description="Identificador da pessoa dona do orçamento.",
        examples=["019f0f8a-1b2c-77bd-9a94-e7d47f72c000"],
    )
    amount: Decimal = Field(description="Valor do orçamento, em BRL.", examples=["500.00"])
    start_date: date = Field(description="Primeiro dia do período (inclusivo).", examples=["2026-06-01"])
    end_date: date = Field(description="Último dia do período (inclusivo).", examples=["2026-06-30"])
    note: str | None = Field(description="Observação livre, se houver.", examples=["mercado"])
    total_spent: Decimal = Field(
        description="Total gasto dentro do período do orçamento, em BRL.",
        examples=["120.00"],
    )
    remaining: Decimal = Field(
        description="Saldo restante (orçamento − total gasto); pode ser negativo.",
        examples=["380.00"],
    )
    created_at: datetime = Field(
        description="Momento de criação, em UTC.",
        examples=["2026-06-28T18:43:18.207963Z"],
    )
