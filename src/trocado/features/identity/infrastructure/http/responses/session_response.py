from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from trocado.features.identity.infrastructure.http.responses.person_response import PersonResponse


class SessionResponse(BaseModel):
    """Response body for a successful sign-up or sign-in.

    The caller stores ``token`` in platform-provided secure storage (Keychain / Keystore) and sends it as
    ``Authorization: Bearer <token>`` on every subsequent authenticated request.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "token": "t_a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
                    "expires_at": "2026-07-29T18:43:18.207963Z",
                    "person": {
                        "id": "019f1a2b-0001-7000-8000-000000000001",
                        "name": "Ana Silva",
                        "email": "ana@example.com",
                    },
                }
            ]
        }
    )

    token: str = Field(
        description="Token opaco de sessão — credencial Bearer para requests autenticados.",
        examples=["t_a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"],
    )
    expires_at: datetime = Field(
        description="Momento de expiração do token, em UTC (ISO-8601).",
        examples=["2026-07-29T18:43:18.207963Z"],
    )
    person: PersonResponse = Field(description="Dados públicos da pessoa autenticada.")
