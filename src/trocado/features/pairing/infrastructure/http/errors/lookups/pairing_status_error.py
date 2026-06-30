from __future__ import annotations

from http import HTTPStatus

from trocado.features.pairing.domain.errors.already_paired_error import AlreadyPairedError
from trocado.features.pairing.domain.errors.invite_code_already_consumed_error import InviteCodeAlreadyConsumedError
from trocado.features.pairing.domain.errors.invite_code_expired_error import InviteCodeExpiredError
from trocado.features.pairing.domain.errors.invite_code_not_found_error import InviteCodeNotFoundError
from trocado.features.pairing.domain.errors.invite_code_revoked_error import InviteCodeRevokedError
from trocado.features.pairing.domain.errors.not_paired_error import NotPairedError
from trocado.features.pairing.domain.errors.person_not_active_error import PersonNotActiveError
from trocado.features.pairing.domain.errors.self_pairing_error import SelfPairingError

PAIRING_STATUS_ERROR: dict[type[Exception], int] = {
    NotPairedError: HTTPStatus.NOT_FOUND,
    SelfPairingError: HTTPStatus.CONFLICT,
    AlreadyPairedError: HTTPStatus.CONFLICT,
    PersonNotActiveError: HTTPStatus.CONFLICT,
    InviteCodeExpiredError: HTTPStatus.CONFLICT,
    InviteCodeRevokedError: HTTPStatus.CONFLICT,
    InviteCodeNotFoundError: HTTPStatus.NOT_FOUND,
    InviteCodeAlreadyConsumedError: HTTPStatus.CONFLICT,
}
