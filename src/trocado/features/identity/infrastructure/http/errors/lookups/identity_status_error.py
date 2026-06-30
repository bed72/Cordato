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
"""Identity-specific domain-error → HTTP-status entries — a pure table (no framework types).

Registered scoped to identity's own Router (mirroring its scoped DI). Cross-cutting core errors
(``InvalidMoneyError``, ``InvalidSessionError``) are handled at the app layer via ``CORE_STATUS_ERROR`` —
they must not be duplicated here. ``InvalidSessionError`` appears here because identity is where the error
is *defined* and explicitly tested; the app-layer entry ensures it is also caught from any other feature's
protected handler.
"""
