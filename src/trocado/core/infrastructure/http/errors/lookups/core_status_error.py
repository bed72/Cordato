from __future__ import annotations

from http import HTTPStatus

from trocado.core.domain.errors.invalid_money_error import InvalidMoneyError
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError

CORE_STATUS_ERROR: dict[type[Exception], int] = {
    InvalidSessionError: HTTPStatus.UNAUTHORIZED,
    InvalidMoneyError: HTTPStatus.UNPROCESSABLE_ENTITY,
}
"""Cross-cutting domain-error → HTTP-status entries, registered once at the **app** layer.

A pure table (no framework types). These errors can be raised from any feature's handler, so they are handled
at the highest scope (app) rather than duplicated in each feature router. ``InvalidMoneyError`` is core because
the money value object lives in the shared kernel. ``InvalidSessionError`` is core because the auth provider
(``CurrentPersonProvider``) is wired at the ``/v1`` router level — it can fire from any protected handler.
Feature tables must NOT re-declare these entries; they belong here exclusively.
"""
