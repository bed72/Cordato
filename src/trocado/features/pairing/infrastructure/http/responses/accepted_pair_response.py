from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AcceptedPairResponse(BaseModel):
    """Response body quando um invite é aceito — retorna os membros brutos do par formado."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "pair_id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c164",
                    "person_a_id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c163",
                    "person_b_id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c165",
                    "paired_since": "2026-06-30T10:05:00Z",
                }
            ]
        }
    )

    pair_id: str = Field(
        description="Identificador opaco do par criado.", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c164"]
    )
    person_a_id: str = Field(
        description="Id do criador do convite (person_a).", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c163"]
    )
    person_b_id: str = Field(
        description="Id de quem aceitou o convite (person_b).", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c165"]
    )
    paired_since: datetime = Field(
        description="Momento em que o par foi formado, em UTC.", examples=["2026-06-30T10:05:00Z"]
    )
