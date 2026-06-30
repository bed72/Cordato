from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class InviteCodeResponse(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c162",
                    "code": "A1B2C3D4",
                    "creator_id": "019f0f8b-0a3f-77bd-9a94-e7d47f72c163",
                    "created_at": "2026-06-30T10:00:00Z",
                    "expires_at": "2026-07-01T10:00:00Z",
                    "consumed_at": None,
                }
            ]
        }
    )

    id: str = Field(
        description="Identificador opaco do invite code.", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c162"]
    )
    code: str = Field(description="Token CSPRNG do convite — compartilhe com o parceiro.", examples=["A1B2C3D4"])
    creator_id: str = Field(
        description="Id da pessoa que criou o convite.", examples=["019f0f8b-0a3f-77bd-9a94-e7d47f72c163"]
    )
    created_at: datetime = Field(description="Momento de criação, em UTC.", examples=["2026-06-30T10:00:00Z"])
    expires_at: datetime = Field(
        description="Momento de expiração, em UTC (~1 dia após criação).", examples=["2026-07-01T10:00:00Z"]
    )
    consumed_at: datetime | None = Field(
        description="Momento de resgate, em UTC. Null enquanto disponível.", examples=[None]
    )
