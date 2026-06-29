from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class PersonResponse(BaseModel):
    """Public profile of a person returned inside a session response."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "019f1a2b-0001-7000-8000-000000000001",
                    "name": "Ana Silva",
                    "email": "ana@example.com",
                }
            ]
        }
    )

    id: str = Field(
        description="Identificador opaco da pessoa (uuid7, time-ordered).",
        examples=["019f1a2b-0001-7000-8000-000000000001"],
    )
    name: str = Field(
        description="Nome completo da pessoa.",
        examples=["Ana Silva"],
    )
    email: str = Field(
        description="Endereço de e-mail da pessoa.",
        examples=["ana@example.com"],
    )
