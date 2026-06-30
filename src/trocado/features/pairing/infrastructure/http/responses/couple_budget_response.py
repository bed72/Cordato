from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class CoupleBudgetResponse(BaseModel):
    """Response body da visão de orçamento do casal — panorama combinado dos orçamentos ativos dos dois parceiros."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "start_date": "2026-06-01",
                    "end_date": "2026-06-30",
                    "amount": "3000.00",
                    "total_spent": "1200.50",
                    "remaining": "1799.50",
                }
            ]
        }
    )

    start_date: date = Field(
        description="Início do período combinado (min dos starts ativos).", examples=["2026-06-01"]
    )
    end_date: date = Field(description="Fim do período combinado (max dos ends ativos).", examples=["2026-06-30"])
    amount: Decimal = Field(description="Soma dos valores dos orçamentos ativos, em BRL.", examples=["3000.00"])
    total_spent: Decimal = Field(
        description="Soma dos gastos dos dois parceiros no período, em BRL.", examples=["1200.50"]
    )
    remaining: Decimal = Field(description="amount − total_spent.", examples=["1799.50"])
