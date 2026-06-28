from __future__ import annotations

from pydantic import BaseModel

from trocado.core.infrastructure.http.errors.responses.error_detail_response import ErrorDetailResponse


class ErrorResponse(BaseModel):
    """The single error envelope for every error — domain, validation, and framework alike.

    Always carries the HTTP ``status``, a programmatic ``code`` (the error kind), and a human ``message`` (pt-BR
    for domain errors). ``errors`` (a list of field details) is **optional**: present only for field-level errors
    (validation) and omitted entirely when there is none — handlers serialize with ``exclude_none``.
    """

    code: str
    status: int
    message: str
    errors: list[ErrorDetailResponse] | None = None
