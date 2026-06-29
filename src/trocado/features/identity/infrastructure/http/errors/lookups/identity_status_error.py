from __future__ import annotations

from http import HTTPStatus

from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.errors.invalid_credentials_error import InvalidCredentialsError
from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError
from trocado.features.identity.domain.errors.invalid_name_error import InvalidNameError
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError
from trocado.features.identity.domain.errors.weak_password_error import WeakPasswordError

IDENTITY_STATUS_ERROR: dict[type[Exception], int] = {
    EmailAlreadyInUseError: HTTPStatus.CONFLICT,
    InvalidSessionError: HTTPStatus.UNAUTHORIZED,
    InvalidCredentialsError: HTTPStatus.UNAUTHORIZED,
    InvalidNameError: HTTPStatus.UNPROCESSABLE_ENTITY,
    InvalidEmailError: HTTPStatus.UNPROCESSABLE_ENTITY,
    WeakPasswordError: HTTPStatus.UNPROCESSABLE_ENTITY,
}
"""Identity's domain-error → HTTP-status entries — a pure table (no framework types).

The identity factory merges this with the core map and builds the unified-envelope handlers **scoped to
identity's own Router** (per route-module, mirroring its scoped DI). Total over the identity errors reachable
at the wired boundary, so none surfaces as an unhandled 500.
"""
