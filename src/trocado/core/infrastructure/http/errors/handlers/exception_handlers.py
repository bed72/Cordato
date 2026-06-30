from __future__ import annotations

from collections.abc import Callable
from http import HTTPStatus
from typing import Any, cast

from litestar import Request, Response
from litestar.exceptions import HTTPException, ValidationException

from trocado.core.infrastructure.http.errors.http.messages_http import http_message
from trocado.core.infrastructure.http.errors.lookups.error_code import error_code
from trocado.core.infrastructure.http.errors.responses.error_detail_response import ErrorDetailResponse
from trocado.core.infrastructure.http.errors.responses.error_response import ErrorResponse
from trocado.core.infrastructure.http.errors.validations.messages_validation import message_validation

ExceptionHandler = Callable[[Request[Any, Any, Any], Any], Response[dict[str, Any]]]


def _to_response(body: ErrorResponse) -> Response[dict[str, Any]]:
    """Serialize the envelope, dropping ``errors`` when absent so non-field errors omit the key entirely."""
    return Response(body.model_dump(exclude_none=True), status_code=body.status)


def _domain_handler(status: int) -> ExceptionHandler:
    """Turn one ``(error type → status)`` row into a handler that frames the unified error envelope.

    The ``code`` is derived from the error class and the ``message`` is the domain's own pt-BR text
    (``str(exc)``) — already generic and non-leaking. Domain errors carry no field details, so ``errors`` is
    omitted.
    """

    def handle(request: Request[Any, Any, Any], exc: Any) -> Response[dict[str, Any]]:
        return _to_response(ErrorResponse(status=status, code=error_code(type(exc)), message=str(exc)))

    return handle


def _field_errors(exc: ValidationException) -> list[ErrorDetailResponse]:
    """Build pt-BR field errors from the underlying Pydantic error (its ``type``/``loc``), if available.

    Litestar wraps the Pydantic failure as ``exc.__cause__`` exposing structured ``errors()`` (``type``, ``loc``);
    each ``type`` is translated to pt-BR. Falls back to ``exc.extra`` (``key`` only) with a generic message when
    the structured cause is absent.
    """
    structured = getattr(exc.__cause__, "errors", None)
    if callable(structured):  # Pydantic exposes errors() as a method; msgspec as a list attribute
        structured = structured()
    if isinstance(structured, list):
        items = cast("list[dict[str, Any]]", structured)
        return [
            ErrorDetailResponse(
                key=".".join(str(part) for part in item["loc"]), message=message_validation(item["type"])
            )
            for item in items
        ]

    raw = exc.extra if isinstance(exc.extra, list) else []
    return [
        ErrorDetailResponse(key=str(item.get("key", "")), message=message_validation(""))
        for item in raw
        if isinstance(item, dict)
    ]


def _validation_handler(request: Request[Any, Any, Any], exc: ValidationException) -> Response[dict[str, Any]]:
    """Frame the framework's validation error as a 422 in the same envelope, with pt-BR field details."""
    body = ErrorResponse(
        code="validation",
        message="Dados inválidos.",
        errors=_field_errors(exc),
        status=HTTPStatus.UNPROCESSABLE_ENTITY,
    )

    return _to_response(body)


def _http_handler(request: Request[Any, Any, Any], exc: HTTPException) -> Response[dict[str, Any]]:
    """Frame any framework-raised HTTP error (malformed JSON 400, unknown route 404, 405, …) in the same envelope.

    Ensures no error escapes in the framework's default shape. The ``code`` and pt-BR ``message`` come from the
    HTTP status (never the framework's English ``detail``, which can leak parser internals like a byte offset).
    """
    try:
        code = HTTPStatus(exc.status_code).name.lower().replace("_", "-")
    except ValueError:
        code = "error"

    return _to_response(ErrorResponse(status=exc.status_code, code=code, message=http_message(exc.status_code)))


def build_domain_exception_handlers(
    status_error: dict[type[Exception], int],
) -> dict[int | type[Exception], ExceptionHandler]:
    """Build a feature's domain-error handlers from its framework-independent error→status table.

    One generated handler per ``(error type → status)`` row, so the table stays the single source of truth. These
    are registered on the **feature's own Router** (scoped per route-module, mirroring its scoped DI providers).
    """
    return {error_type: _domain_handler(status) for error_type, status in status_error.items()}


def build_core_exception_handlers(
    core_status_error: dict[type[Exception], int],
) -> dict[int | type[Exception], ExceptionHandler]:
    """Build the cross-cutting handlers registered once at the **app** layer.

    Covers three concerns:
    - ``ValidationException`` → 422 with pt-BR field details.
    - ``HTTPException`` base → framework-raised HTTP errors (unknown route 404, 405, …) framed in the envelope.
    - Core domain errors (``core_status_error``) — e.g. ``InvalidMoneyError``, ``InvalidSessionError`` — that
      can be raised from any feature's handler. Registering them here means feature routers only declare their
      own errors, keeping DI and error handling at the same layer of concern.

    Litestar resolves the most specific registered type across layers (feature router → /v1 router → app), so
    a feature's own domain error wins at the feature level and core errors are caught here.
    """
    return {
        HTTPException: _http_handler,
        ValidationException: _validation_handler,
        **build_domain_exception_handlers(core_status_error),
    }
