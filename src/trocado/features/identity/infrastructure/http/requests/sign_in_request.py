from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class SignInRequest(BaseModel):
    """Request body for ``POST /v1/authentication/sign-in``."""

    model_config = ConfigDict(
        json_schema_extra={"examples": [{"email": "ana@example.com", "password": "senha-segura-123"}]}
    )

    email: str = Field(
        description="E-mail da pessoa.",
        examples=["ana@example.com"],
    )
    password: str = Field(
        description="Senha em texto puro — verificada contra o hash armazenado, nunca persistida.",
        examples=["senha-segura-123"],
    )
