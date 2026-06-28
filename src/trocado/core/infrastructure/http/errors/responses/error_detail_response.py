from __future__ import annotations

from pydantic import BaseModel


class ErrorDetailResponse(BaseModel):
    """One field-level error inside an error response — which field (``key``) failed and why (``message``)."""

    key: str
    message: str
