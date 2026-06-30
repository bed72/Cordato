from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class UpdateBudgetRequest(BaseModel):
    """Request body for ``PATCH /v1/budgets/{budget_id}``.

    Full-replacement semantics: every editable field is supplied and overwrites the stored value.
    The shape mirrors ``CreateBudgetRequest`` because the same fields are editable. Domain rules
    (amount greater than zero, start not after end, non-overlap invariant) are enforced by the
    use case and entity, not duplicated here.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"amount": "600.00", "start_date": "2026-07-01", "end_date": "2026-07-31", "note": "julho"}]
        }
    )

    amount: Decimal = Field(
        description="Valor do orçamento, em BRL — decimal exato (centavos), maior que zero.",
        examples=["600.00"],
    )
    start_date: date = Field(
        description="Primeiro dia do período do orçamento (inclusivo).",
        examples=["2026-07-01"],
    )
    end_date: date = Field(
        description="Último dia do período do orçamento (inclusivo); não anterior ao início.",
        examples=["2026-07-31"],
    )
    note: str | None = Field(
        default=None,
        description="Observação livre, opcional.",
        examples=["julho"],
    )
