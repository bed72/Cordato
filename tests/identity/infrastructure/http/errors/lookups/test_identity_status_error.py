from http import HTTPStatus

from trocado.features.identity.domain.errors.email_already_in_use_error import EmailAlreadyInUseError
from trocado.features.identity.domain.errors.invalid_credentials_error import InvalidCredentialsError
from trocado.features.identity.domain.errors.invalid_email_error import InvalidEmailError
from trocado.features.identity.domain.errors.invalid_name_error import InvalidNameError
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError
from trocado.features.identity.domain.errors.weak_password_error import WeakPasswordError
from trocado.features.identity.infrastructure.http.errors.lookups.identity_status_error import IDENTITY_STATUS_ERROR


def test_invalid_credentials_maps_to_401() -> None:
    assert IDENTITY_STATUS_ERROR[InvalidCredentialsError] == HTTPStatus.UNAUTHORIZED


def test_invalid_session_maps_to_401() -> None:
    assert IDENTITY_STATUS_ERROR[InvalidSessionError] == HTTPStatus.UNAUTHORIZED


def test_email_already_in_use_maps_to_409() -> None:
    assert IDENTITY_STATUS_ERROR[EmailAlreadyInUseError] == HTTPStatus.CONFLICT


def test_invalid_email_maps_to_422() -> None:
    assert IDENTITY_STATUS_ERROR[InvalidEmailError] == HTTPStatus.UNPROCESSABLE_ENTITY


def test_invalid_name_maps_to_422() -> None:
    assert IDENTITY_STATUS_ERROR[InvalidNameError] == HTTPStatus.UNPROCESSABLE_ENTITY


def test_weak_password_maps_to_422() -> None:
    assert IDENTITY_STATUS_ERROR[WeakPasswordError] == HTTPStatus.UNPROCESSABLE_ENTITY


def test_table_is_total_over_known_errors() -> None:
    expected = {
        InvalidNameError,
        WeakPasswordError,
        InvalidEmailError,
        InvalidSessionError,
        EmailAlreadyInUseError,
        InvalidCredentialsError,
    }

    assert set(IDENTITY_STATUS_ERROR.keys()) == expected
