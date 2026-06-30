from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class CreateExpenseRequest(BaseModel):
    """Request body for ``POST /v1/expenses``.

    Validates only the structural shape — presence and types. The domain rules (amount greater than
    zero, centavo precision, date without time) stay in the value objects and entity; they are not
    duplicated here. The field descriptions/examples feed the OpenAPI schema and the Swagger "Try it out" form.
    """

    model_config = ConfigDict(
        json_schema_extra={"examples": [{"amount": "49.90", "occurred_on": "2026-06-28", "description": "almoço"}]}
    )

    amount: Decimal = Field(
        description="Valor da despesa, em BRL — decimal exato (centavos), maior que zero.",
        examples=["49.90"],
    )
    occurred_on: date = Field(
        description="Data em que o gasto ocorreu (sem horário).",
        examples=["2026-06-28"],
    )
    description: str | None = Field(
        default=None,
        description="Descrição livre, opcional. Espaços nas bordas são removidos; vazio vira ausente.",
        examples=["almoço"],
    )
