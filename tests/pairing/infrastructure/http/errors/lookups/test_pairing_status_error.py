from http import HTTPStatus

from trocado.features.pairing.domain.errors.already_paired_error import AlreadyPairedError
from trocado.features.pairing.domain.errors.invite_code_already_consumed_error import InviteCodeAlreadyConsumedError
from trocado.features.pairing.domain.errors.invite_code_expired_error import InviteCodeExpiredError
from trocado.features.pairing.domain.errors.invite_code_not_found_error import InviteCodeNotFoundError
from trocado.features.pairing.domain.errors.invite_code_revoked_error import InviteCodeRevokedError
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError
from trocado.features.pairing.domain.errors.person_not_active_error import PersonNotActiveError
from trocado.features.pairing.domain.errors.self_pairing_error import SelfPairingError
from trocado.features.pairing.infrastructure.http.errors.lookups.pairing_status_error import PAIRING_STATUS_ERROR


def test_each_pairing_error_maps_to_its_status() -> None:
    assert len(PAIRING_STATUS_ERROR) == 8
    assert PAIRING_STATUS_ERROR[NotPairedError] == HTTPStatus.NOT_FOUND
    assert PAIRING_STATUS_ERROR[SelfPairingError] == HTTPStatus.CONFLICT
    assert PAIRING_STATUS_ERROR[AlreadyPairedError] == HTTPStatus.CONFLICT
    assert PAIRING_STATUS_ERROR[PersonNotActiveError] == HTTPStatus.CONFLICT
    assert PAIRING_STATUS_ERROR[InviteCodeExpiredError] == HTTPStatus.CONFLICT
    assert PAIRING_STATUS_ERROR[InviteCodeRevokedError] == HTTPStatus.CONFLICT
    assert PAIRING_STATUS_ERROR[InviteCodeNotFoundError] == HTTPStatus.NOT_FOUND
    assert PAIRING_STATUS_ERROR[InviteCodeAlreadyConsumedError] == HTTPStatus.CONFLICT


def test_invite_creation_reachable_errors_are_covered() -> None:
    """POST /v1/invites raises no domain errors — nothing to verify."""
    pass


def test_invite_accept_reachable_errors_are_covered() -> None:
    """Totality over errors POST /v1/invites/{code}/accept can raise."""
    for error in (
        SelfPairingError,
        AlreadyPairedError,
        PersonNotActiveError,
        InviteCodeExpiredError,
        InviteCodeRevokedError,
        InviteCodeNotFoundError,
        InviteCodeAlreadyConsumedError,
    ):
        assert error in PAIRING_STATUS_ERROR


def test_pair_operations_reachable_errors_are_covered() -> None:
    """Totality over errors on /v1/pair endpoints that can raise NotPairedError."""
    assert NotPairedError in PAIRING_STATUS_ERROR
