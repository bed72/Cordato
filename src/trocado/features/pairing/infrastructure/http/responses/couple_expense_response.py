from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class CoupleExpenseResponse(BaseModel):
    """Response body de uma despesa na visão do casal — marcada com perspectiva `mine`/`theirs`."""

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
                    "perspective": "mine",
                }
            ]
        }
    )

    id: str = Field(description="Identificador opaco da despesa.", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c162"])
    person_id: str = Field(
        description="Id da pessoa dona da despesa.", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c163"]
    )
    amount: Decimal = Field(description="Valor da despesa, em BRL.", examples=["49.90"])
    occurred_on: date = Field(description="Data em que o gasto ocorreu (sem horário).", examples=["2026-06-28"])
    description: str | None = Field(description="Descrição livre, se houver.", examples=["almoço"])
    created_at: datetime = Field(
        description="Momento de criação do registro, em UTC.", examples=["2026-06-28T18:43:18.207963Z"]
    )
    perspective: str = Field(
        description='Perspectiva relativa ao reader: `"mine"` (minha despesa) ou `"theirs"` (do parceiro).',
        examples=["mine"],
    )
