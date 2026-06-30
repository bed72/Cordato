from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class ExpenseResponse(BaseModel):
    """Response body for an expense — the expense read-model serialized for the client.

    Carries no budget reference of any kind, mirroring ``ExpenseData``: budget belonging is derived
    at read-time and never stored or serialized. The field descriptions/examples feed the OpenAPI schema.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c162",
                    "person_id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c163",
                    "amount": "49.90",
                    "occurred_on": "2026-06-28",
                    "description": "almoço",
                    "created_at": "2026-06-28T18:43:18.207963Z",
                }
            ]
        }
    )

    id: str = Field(
        description="Identificador opaco da despesa (uuid7, time-ordered).",
        examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c162"],
    )
    person_id: str = Field(
        description="Identificador da pessoa dona da despesa.",
        examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c163"],
    )
    amount: Decimal = Field(description="Valor da despesa, em BRL.", examples=["49.90"])
    occurred_on: date = Field(description="Data em que o gasto ocorreu (sem horário).", examples=["2026-06-28"])
    description: str | None = Field(description="Descrição livre, se houver.", examples=["almoço"])
    created_at: datetime = Field(
        description="Momento de criação do registro, em UTC.",
        examples=["2026-06-28T18:43:18.207963Z"],
    )
