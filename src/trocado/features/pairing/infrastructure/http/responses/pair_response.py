from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class PairResponse(BaseModel):
    """Response body do par atual — lido da perspectiva do reader (parceiro resolvido no lado do reader)."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "pair_id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c164",
                    "partner_id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c165",
                    "partner_name": "Ana Lima",
                    "paired_since": "2026-06-30T10:05:00Z",
                }
            ]
        }
    )

    pair_id: str = Field(description="Identificador opaco do par.", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c164"])
    partner_id: str = Field(
        description="Id do parceiro (o outro membro do par).", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c165"]
    )
    partner_name: str = Field(description="Nome atual do parceiro.", examples=["Ana Lima"])
    paired_since: datetime = Field(
        description="Momento em que o par foi formado, em UTC.", examples=["2026-06-30T10:05:00Z"]
    )
