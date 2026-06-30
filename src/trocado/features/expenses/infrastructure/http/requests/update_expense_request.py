from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class UpdateExpenseRequest(BaseModel):
    """Request body for ``PATCH /v1/expenses/{expense_id}``.

    Full-replacement semantics: every editable field is required and overwrites the stored value.
    Despite the HTTP verb being ``PATCH``, the domain contract is a complete overwrite of ``amount``,
    ``occurred_on``, and ``description`` — consistent with ``UpdateExpenseUseCase``.
    """

    model_config = ConfigDict(
        json_schema_extra={"examples": [{"amount": "55.00", "occurred_on": "2026-06-29", "description": "jantar"}]}
    )

    amount: Decimal = Field(
        description="Novo valor da despesa, em BRL — decimal exato (centavos), maior que zero.",
        examples=["55.00"],
    )
    occurred_on: date = Field(
        description="Nova data em que o gasto ocorreu (sem horário).",
        examples=["2026-06-29"],
    )
    description: str | None = Field(
        default=None,
        description="Nova descrição livre, opcional. Espaços nas bordas são removidos; vazio vira ausente.",
        examples=["jantar"],
    )
