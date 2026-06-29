from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class SignUpRequest(BaseModel):
    """Request body for ``POST /v1/authentication/sign-up``.

    Validates only the structural shape — field presence and type. Domain rules (valid email format,
    password strength, name length) are enforced by the use case's value objects and are not duplicated here.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"name": "Ana Silva", "email": "ana@example.com", "password": "senha-segura-123"}]
        }
    )

    name: str = Field(
        description="Nome completo da pessoa.",
        examples=["Ana Silva"],
    )
    email: str = Field(
        description="Endereço de e-mail — deve ser único no sistema.",
        examples=["ana@example.com"],
    )
    password: str = Field(
        description="Senha em texto puro — nunca é armazenada, apenas o hash Argon2.",
        examples=["senha-segura-123"],
    )
