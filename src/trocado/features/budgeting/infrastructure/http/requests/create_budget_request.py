from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class CreateBudgetRequest(BaseModel):
    """Request body for ``POST /v1/budgets``.

    Validates only the *structural* shape — that the fields are present and of the right type (a valid
    decimal amount, ISO dates, an optional note). The domain rules (amount greater than zero, start no
    later than end, centavo precision) stay in the value objects and entity and are deliberately **not**
    duplicated here: a single source of truth, enforced once. The field descriptions/examples feed the
    OpenAPI schema (and so the Swagger "Try it out" form).
    """

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"amount": "500.00", "start_date": "2026-06-01", "end_date": "2026-06-30", "note": "mercado"}]
        }
    )

    amount: Decimal = Field(
        description="Valor do orçamento, em BRL — decimal exato (centavos), maior que zero.",
        examples=["500.00"],
    )
    start_date: date = Field(
        description="Primeiro dia do período do orçamento (inclusivo).",
        examples=["2026-06-01"],
    )
    end_date: date = Field(
        description="Último dia do período do orçamento (inclusivo); não anterior ao início.",
        examples=["2026-06-30"],
    )
    note: str | None = Field(
        default=None,
        description="Observação livre, opcional.",
        examples=["mercado"],
    )
