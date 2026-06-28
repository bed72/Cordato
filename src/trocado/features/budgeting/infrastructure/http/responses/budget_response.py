from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class BudgetResponse(BaseModel):
    """Response body for a created budget — the budget read-model serialized for the client.

    Carries no spend (``total_spent``/``remaining`` belong to the enriched active-budget read), mirroring
    ``BudgetData``: this is the plain create response. The field descriptions/examples feed the OpenAPI schema.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c162",
                    "amount": "500.00",
                    "start_date": "2026-06-01",
                    "end_date": "2026-06-30",
                    "note": "Orçamento de Julho",
                    "created_at": "2026-06-28T18:43:18.207963Z",
                }
            ]
        }
    )

    id: str = Field(
        description="Identificador opaco do orçamento (uuid7, time-ordered).",
        examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c162"],
    )
    amount: Decimal = Field(description="Valor do orçamento, em BRL.", examples=["500.00"])
    start_date: date = Field(description="Primeiro dia do período (inclusivo).", examples=["2026-06-01"])
    end_date: date = Field(description="Último dia do período (inclusivo).", examples=["2026-06-30"])
    note: str | None = Field(description="Observação livre, se houver.", examples=["mercado"])
    created_at: datetime = Field(
        description="Momento de criação, em UTC.",
        examples=["2026-06-28T18:43:18.207963Z"],
    )
